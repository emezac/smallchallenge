require 'sqlite3'
require 'securerandom'
require 'digest'
require 'openssl'
require 'json'
require 'uri'

module Gateway
  class Conflict < StandardError; end
  class Invalid < StandardError; end

  # A single SQLite transaction serializes state changes and their audit events.
  # The confirmed row itself is the durable work queue, avoiding enqueue gaps.
  class Domain
    def initialize(path:, audit_key:, origin:, clock: -> { Time.now.to_i }, audit_key_id: 'v1', audit_previous_keys: {})
      raise Invalid, 'audit key must have at least 32 bytes' if audit_key.bytesize < 32
      uri = URI(origin)
      raise Invalid, 'HTTPS origin required' unless uri.scheme == 'https' && uri.host && !uri.userinfo && !uri.query && !uri.fragment && ['', '/'].include?(uri.path)
      @key, @origin, @clock = audit_key, origin.delete_suffix('/'), clock
      raise Invalid, 'invalid audit key ID' unless /\A[a-zA-Z0-9_-]{1,32}\z/.match?(audit_key_id)
      @key_id = audit_key_id
      @keys = audit_previous_keys.merge(audit_key_id => audit_key)
      raise Invalid, 'invalid historical keys' unless @keys.values.all? { |k| k.is_a?(String) && k.bytesize >= 32 }
      @db = SQLite3::Database.new(path)
      @db.results_as_hash = true
      @db.busy_timeout = 5000
      @db.execute_batch <<~SQL
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS cards (id TEXT PRIMARY KEY, status TEXT NOT NULL);
        INSERT OR IGNORE INTO cards VALUES ('card_demo', 'ACTIVE');
        CREATE TABLE IF NOT EXISTS actions (
          id TEXT PRIMARY KEY, status TEXT NOT NULL, reason TEXT NOT NULL,
          expires INTEGER NOT NULL, grant_hash TEXT UNIQUE, consumed INTEGER,
          session_hash TEXT UNIQUE, csrf_hash TEXT, read_expires INTEGER);
        CREATE UNIQUE INDEX IF NOT EXISTS one_active ON actions ((1))
          WHERE status IN ('PENDING_CONFIRMATION','CONFIRMED','EXECUTING','EXECUTION_UNKNOWN');
        CREATE TABLE IF NOT EXISTS effects (action_id TEXT PRIMARY KEY, result TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS execution_attempts (id INTEGER PRIMARY KEY, action_id TEXT NOT NULL, status TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS audit (seq INTEGER PRIMARY KEY, payload TEXT NOT NULL,
          prev_hash TEXT NOT NULL, entry_hash TEXT NOT NULL, signature TEXT NOT NULL);
      SQL
    end

    def close = @db.close
    def card = { card_alias: 'card_demo', last4: '4242', status: @db.get_first_value('SELECT status FROM cards') }
    def digest(value) = Digest::SHA256.hexdigest(value)

    def transaction
      @db.execute('BEGIN IMMEDIATE')
      result = yield
      @db.execute('COMMIT')
      result
    rescue Exception
      @db.execute('ROLLBACK') if @db.transaction_active?
      raise
    end

    def audit(event, id)
      payload = JSON.generate({ action: id, event: event, key_id: @key_id, schema_version: 2, time: @clock.call })
      previous = @db.get_first_value('SELECT entry_hash FROM audit ORDER BY seq DESC LIMIT 1') || '0' * 64
      hash = digest(payload + previous)
      signature = OpenSSL::HMAC.hexdigest('SHA256', @key, hash)
      @db.execute('INSERT INTO audit(payload,prev_hash,entry_hash,signature) VALUES (?,?,?,?)', [payload, previous, hash, signature])
    end

    def propose(card_id:, action_type:, reason_code:)
      raise Invalid, 'unsupported proposal' unless card_id == 'card_demo' && action_type == 'CARD_BLOCK' && %w[LOST_CARD STOLEN_CARD SUSPECTED_FRAUD OTHER].include?(reason_code)
      transaction do
        @db.execute("SELECT id FROM actions WHERE status='PENDING_CONFIRMATION' AND expires<=?", [@clock.call]).each do |row|
          @db.execute("UPDATE actions SET status='EXPIRED' WHERE id=?", [row['id']])
          audit('EXPIRED', row['id'])
        end
        raise Conflict, 'already blocked' if card[:status] == 'BLOCKED'
        existing = @db.get_first_row("SELECT * FROM actions WHERE status IN ('PENDING_CONFIRMATION','CONFIRMED','EXECUTING','EXECUTION_UNKNOWN')")
        if existing
          public_status(existing)
        else
          id, token = 'act_' + SecureRandom.hex(16), SecureRandom.urlsafe_base64(32)
          @db.execute("INSERT INTO actions(id,status,reason,expires,grant_hash) VALUES (?,'PENDING_CONFIRMATION',?,?,?)", [id, reason_code, @clock.call + 300, digest(token)])
          audit('PROPOSED', id)
          { action_alias: id, status: 'PENDING_CONFIRMATION', expires_at: @clock.call + 300, confirmation_url: "#{@origin}/c/#{token}" }
        end
      end
    end

    def exchange(token)
      transaction do
        row = @db.get_first_row('SELECT * FROM actions WHERE grant_hash=?', [digest(token)])
        raise Conflict, 'invalid or expired link' unless row && !row['consumed'] && row['status'] == 'PENDING_CONFIRMATION' && row['expires'] > @clock.call
        session, csrf = SecureRandom.urlsafe_base64(32), SecureRandom.urlsafe_base64(32)
        @db.execute('UPDATE actions SET consumed=1,session_hash=?,csrf_hash=?,read_expires=? WHERE id=?', [digest(session), digest(csrf), @clock.call + 900, row['id']])
        audit('CONFIRMATION_OPENED', row['id'])
        { action_alias: row['id'], session: session, csrf: csrf }
      end
    end

    def session_status(id, session)
      row = @db.get_first_row('SELECT * FROM actions WHERE id=? AND session_hash=? AND read_expires>?', [id, digest(session), @clock.call])
      raise Conflict, 'invalid session' unless row
      public_status(row)
    end

    def decide(id:, session:, csrf:, decision:)
      raise Invalid, 'invalid decision' unless %w[confirm reject].include?(decision)
      transaction do
        session_status(id, session)
        row = @db.get_first_row('SELECT * FROM actions WHERE id=?', [id])
        raise Conflict, 'decision not allowed' unless row['status'] == 'PENDING_CONFIRMATION' && row['expires'] > @clock.call && row['csrf_hash'] == digest(csrf)
        state = decision == 'confirm' ? 'CONFIRMED' : 'REJECTED'
        @db.execute('UPDATE actions SET status=?,csrf_hash=NULL WHERE id=?', [state, id])
        audit(state, id)
        { action_alias: id, status: state }
      end
    end

    # Simulated effect and final state commit together. Re-running after a crash
    # finds either the confirmed work or the completed transaction, never half an effect.
    def work(fault: nil)
      raise Invalid, 'unsupported test fault' unless [nil, :known_failure, :lost_response].include?(fault)
      transaction do
        row = @db.get_first_row("SELECT * FROM actions WHERE status='CONFIRMED' LIMIT 1")
        if row
          id = row['id']
          @db.execute("UPDATE actions SET status='EXECUTING' WHERE id=?", [id])
          audit('EXECUTING', id)
          if fault == :known_failure
            state, attempt = 'EXECUTION_FAILED', 'FAILED'
          else
            @db.execute("INSERT OR IGNORE INTO effects VALUES (?,'BLOCKED')", [id])
            @db.execute("UPDATE cards SET status='BLOCKED'")
            state, attempt = fault == :lost_response ? ['EXECUTION_UNKNOWN', 'UNKNOWN'] : ['EXECUTED', 'SUCCEEDED']
          end
          @db.execute('INSERT INTO execution_attempts(action_id,status) VALUES (?,?)', [id, attempt])
          @db.execute('UPDATE actions SET status=? WHERE id=?', [state, id])
          audit(state, id)
          id
        end
      end
    end

    def reconcile
      transaction do
        @db.execute("SELECT id FROM actions WHERE status='EXECUTION_UNKNOWN'").each do |row|
          next unless @db.get_first_value('SELECT result FROM effects WHERE action_id=?', [row['id']]) == 'BLOCKED'
          @db.execute("UPDATE actions SET status='EXECUTED' WHERE id=?", [row['id']])
          audit('RECONCILED', row['id'])
        end
      end
    end

    # Local demonstration reset: preserve actions, effects and audit history.
    # Refuse while an action can still mutate or require reconciliation.
    def reset_demo
      transaction do
        active = @db.get_first_value("SELECT 1 FROM actions WHERE status IN ('PENDING_CONFIRMATION','CONFIRMED','EXECUTING','EXECUTION_UNKNOWN') LIMIT 1")
        raise Conflict, 'active action prevents reset' if active
        @db.execute("UPDATE cards SET status='ACTIVE' WHERE id='card_demo'")
        audit('DEMO_RESET', 'card_demo')
        card
      end
    end

    def status(id)
      expire_pending
      row = @db.get_first_row('SELECT * FROM actions WHERE id=?', [id])
      raise Invalid, 'unknown action' unless row
      public_status(row)
    end

    def public_status(row) = { action_alias: row['id'], status: row['status'], expires_at: row['expires'] }

    def expire_pending
      transaction do
        @db.execute("SELECT id FROM actions WHERE status='PENDING_CONFIRMATION' AND expires<=?", [@clock.call]).each do |row|
          @db.execute("UPDATE actions SET status='EXPIRED' WHERE id=?", [row['id']])
          audit('EXPIRED', row['id'])
        end
      end
    end

    def verify_audit
      previous = '0' * 64
      sequence = 0
      @db.execute('SELECT * FROM audit ORDER BY seq').all? do |row|
        sequence += 1
        payload = JSON.parse(row['payload'])
        next false unless payload.is_a?(Hash) && [nil, 2].include?(payload['schema_version'])
        key = @keys[payload.fetch('key_id', 'v1')]
        next false unless key && row['seq'] == sequence
        hash = digest(row['payload'] + previous)
        valid = row['prev_hash'] == previous && row['entry_hash'] == hash && row['signature'] == OpenSSL::HMAC.hexdigest('SHA256', key, hash)
        previous = hash
        valid
      end
    rescue JSON::ParserError, TypeError
      false
    end
  end
end
