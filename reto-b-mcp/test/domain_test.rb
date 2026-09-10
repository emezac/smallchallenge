require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'

class GatewayTestCase < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('gateway-test-')
    @now = 1000
    @d = Gateway::Domain.new(path: File.join(@dir, 'test.sqlite3'), audit_key: 'a' * 32, origin: 'https://example.test', clock: -> { @now })
  end

  def teardown
    @d.close
    FileUtils.remove_entry(@dir)
  end

  def proposal
    @d.propose(card_id: 'card_demo', action_type: 'CARD_BLOCK', reason_code: 'LOST_CARD')
  end

end

class DomainTest < GatewayTestCase

  def test_confirm_and_worker_are_separate_and_idempotent
    p = proposal
    assert_equal 'ACTIVE', @d.card[:status]
    assert_nil @d.work
    grant = @d.exchange(p[:confirmation_url].split('/').last)
    @d.decide(id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'confirm')
    assert_equal 'ACTIVE', @d.card[:status]
    assert_equal p[:action_alias], @d.work
    assert_nil @d.work
    assert_equal 'BLOCKED', @d.card[:status]
    assert @d.verify_audit
  end

  def test_demo_reset_preserves_history_and_refuses_active_action
    pending = proposal
    assert_raises(Gateway::Conflict) { @d.reset_demo }
    grant = @d.exchange(pending[:confirmation_url].split('/').last)
    @d.decide(id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'confirm')
    @d.work
    assert_equal 'BLOCKED', @d.card[:status]

    assert_equal 'ACTIVE', @d.reset_demo[:status]
    assert_equal 'EXECUTED', @d.status(grant[:action_alias])[:status]
    assert @d.verify_audit
  end

  def test_duplicate_does_not_reconstruct_token
    first, second = proposal, proposal
    assert_equal first[:action_alias], second[:action_alias]
    refute second.key?(:confirmation_url)
  end

  def test_replay_csrf_and_rejection
    p = proposal
    token = p[:confirmation_url].split('/').last
    grant = @d.exchange(token)
    assert_raises(Gateway::Conflict) { @d.exchange(token) }
    args = { id: grant[:action_alias], session: grant[:session], csrf: grant[:csrf], decision: 'reject' }
    assert_raises(Gateway::Conflict) { @d.decide(**args.merge(csrf: 'forged')) }
    assert_raises(Gateway::Conflict) { @d.decide(**args.merge(session: 'forged')) }
    @d.decide(**args)
    assert_raises(Gateway::Conflict) { @d.decide(**args) }
    assert_nil @d.work
    assert_equal 'ACTIVE', @d.card[:status]
  end

  def test_expiry
    p = proposal
    @now += 301
    assert_raises(Gateway::Conflict) { @d.exchange(p[:confirmation_url].split('/').last) }
    refute_equal p[:action_alias], proposal[:action_alias]
    assert_equal 'EXPIRED', @d.status(p[:action_alias])[:status]
  end
end
