# Builds absolute URLs for links embedded in outgoing email.
#
# Verification and password-reset emails point at HTML landing pages served
# by this API (see PagesController). The base host is configurable so the
# same code works in local dev and against a public deployment; once the
# Phase 3 frontend exists these can be repointed at frontend routes.
module AppUrl
  DEFAULT_BASE = 'http://localhost:3001'.freeze

  class << self
    def base
      ENV['APP_BASE_URL'].presence&.chomp('/') || DEFAULT_BASE
    end

    # SecureRandom.urlsafe_base64 tokens are already URL-safe, so no escaping.
    def verify_email(token)
      "#{base}/verify_email?token=#{token}"
    end

    def reset_password(token)
      "#{base}/reset_password?token=#{token}"
    end
  end
end
