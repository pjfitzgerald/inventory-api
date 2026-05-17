class JsonWebToken
  ALGORITHM = 'HS256'.freeze
  DEFAULT_TTL = 14.days

  class << self
    def encode(payload, ttl: DEFAULT_TTL)
      JWT.encode(payload.merge(exp: ttl.from_now.to_i), secret, ALGORITHM)
    end

    # Returns the payload as a symbol-keyed hash, or nil if the token is
    # missing, malformed, tampered with, or expired.
    def decode(token)
      return nil if token.blank?

      body, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      body.symbolize_keys
    rescue JWT::DecodeError
      nil
    end

    private

    def secret
      ENV['AUTH_SECRET'].presence || Rails.application.secret_key_base
    end
  end
end
