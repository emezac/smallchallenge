require 'minitest/autorun'
require 'rack/mock'
require_relative '../lib/authentication'

class AuthenticationTest < Minitest::Test
  def setup
    @key = OpenSSL::PKey::RSA.generate(2048)
    @auth = Gateway::Authentication.new(issuer: 'https://issuer.test', audience: 'https://gateway.test/mcp', public_key: @key.public_key.to_pem, revoked_ids: ['revoked'])
  end

  def token(changes = {}, key: @key)
    JWT.encode({ iss: 'https://issuer.test', aud: 'https://gateway.test/mcp', sub: 'demo', jti: 'valid', exp: Time.now.to_i + 300, scope: 'bank:actions' }.merge(changes), key, 'RS256')
  end

  def check(value)
    @auth.call(Rack::Request.new(Rack::MockRequest.env_for('https://gateway.test/mcp', 'HTTP_AUTHORIZATION' => "Bearer #{value}")))
  end

  def test_valid_and_invalid_tokens
    assert check(token)
    [{ iss: 'https://other.test' }, { aud: 'https://other.test' }, { exp: 1 }, { scope: 'other' }, { jti: 'revoked' }, { nbf: Time.now.to_i + 300 }, { sub: nil }].each { |change| refute check(token(change)), change.inspect }
    refute check('malformed')
    refute check(token({}, key: OpenSSL::PKey::RSA.generate(2048)))
    assert_equal ['header'], @auth.metadata[:bearer_methods_supported]
  end

  def test_jwks_selects_only_the_matching_rsa_signing_key
    jwk = JWT::JWK.new(@key.public_key, kid: 'current', use: 'sig', alg: 'RS256').export
    auth = Gateway::Authentication.new(issuer: 'https://issuer.test', audience: 'https://gateway.test/mcp',
      jwks: JSON.generate('keys' => [jwk]))
    payload = { iss: 'https://issuer.test', aud: 'https://gateway.test/mcp', sub: 'demo',
      jti: 'valid', exp: Time.now.to_i + 300, scope: 'bank:actions' }
    valid = JWT.encode(payload, @key, 'RS256', kid: 'current')
    unknown = JWT.encode(payload, @key, 'RS256', kid: 'unknown')
    request = ->(value) { Rack::Request.new(Rack::MockRequest.env_for('https://gateway.test/mcp', 'HTTP_AUTHORIZATION' => "Bearer #{value}")) }
    assert auth.call(request.call(valid))
    refute auth.call(request.call(unknown))
    refute auth.call(request.call(JWT.encode(payload, @key, 'RS256')))
  end
end
