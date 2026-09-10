require_relative 'domain_test'

class PersistenceTest < GatewayTestCase
  def second_connection
    Gateway::Domain.new(path: File.join(@dir, 'test.sqlite3'), audit_key: 'a' * 32, origin: 'https://example.test', clock: -> { @now })
  end

  def test_proposals_across_connections
    connections = 4.times.map { second_connection }
    rows = connections.map { |db| Thread.new { db.propose(card_id: 'card_demo', action_type: 'CARD_BLOCK', reason_code: 'LOST_CARD') } }.map(&:value)
    assert_equal 1, rows.map { |r| r[:action_alias] }.uniq.size
    assert_equal 1, rows.count { |r| r[:confirmation_url] }
    assert @d.verify_audit
  ensure
    connections&.each(&:close)
  end

  def test_work_survives_connection_restart
    p = proposal
    grant = @d.exchange(p[:confirmation_url].split('/').last)
    @d.decide(id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'confirm')
    other = second_connection
    assert_equal p[:action_alias], other.work
    assert_nil @d.work
    assert_equal 'EXECUTED', @d.status(p[:action_alias])[:status]
  ensure
    other&.close
  end

  def test_audit_tamper_detection
    proposal
    db = SQLite3::Database.new(File.join(@dir, 'test.sqlite3'))
    db.execute("UPDATE audit SET payload='{}' WHERE seq=1")
    refute @d.verify_audit
  ensure
    db&.close
  end

  def confirm_proposal
    p = proposal
    grant = @d.exchange(p[:confirmation_url].split('/').last)
    @d.decide(id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'confirm')
    p[:action_alias]
  end

  def test_lost_response_reconciles_without_second_effect
    id = confirm_proposal
    @d.work(fault: :lost_response)
    assert_equal 'EXECUTION_UNKNOWN', @d.status(id)[:status]
    assert_nil @d.work
    @d.reconcile
    assert_equal 'EXECUTED', @d.status(id)[:status]
    db = SQLite3::Database.new(File.join(@dir, 'test.sqlite3'))
    assert_equal 1, db.get_first_value('SELECT count(*) FROM effects')
  ensure
    db&.close
  end

  def test_known_failure_does_not_block_card
    id = confirm_proposal
    @d.work(fault: :known_failure)
    assert_equal 'EXECUTION_FAILED', @d.status(id)[:status]
    assert_equal 'ACTIVE', @d.card[:status]
    assert_nil @d.work
  end
end
