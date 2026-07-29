# Rate limiting for the authentication endpoints.
#
# These are the only unauthenticated, publicly reachable POST endpoints in the
# app, so they're the ones worth protecting: password guessing on /auth/login,
# token guessing on /auth/verify and /auth/reset_password, and mailbox abuse
# via /auth/signup and /auth/request_password_reset (both send real email at
# our expense).
#
# Deliberately NOT throttled: /api/v1/items. A CSV or backup import issues one
# POST per row, so a 650-item restore would trip any sane request limit. Those
# endpoints require a valid JWT anyway, so they're not an anonymous attack
# surface.
#
# Counters live in a Rack::Attack-owned MemoryStore rather than Rails.cache:
# the test env uses a :null_store (which silently never counts) and production
# has no cache configured. Puma runs single-process here (workers are
# commented out in config/puma.rb), so one in-process store sees every
# request. If this ever moves to clustered Puma or more than one container,
# swap this for a shared store (Redis/Memcached) or the limits become
# per-process and effectively N times looser.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

class Rack::Attack
  # The API always runs behind the frontend's nginx (and behind Railway's
  # edge, and Tailscale Serve on the T480), so REMOTE_ADDR is a proxy, not a
  # client. Rack::Attack is inserted after ActionDispatch::RemoteIp, which has
  # already worked the real client out of the X-Forwarded-For chain and
  # honours config.action_dispatch.trusted_proxies — so use its answer rather
  # than Rack::Request's own weaker guess. Without this every request through
  # the proxy would share one throttle bucket.
  class Request < ::Rack::Request
    def ip
      @remote_ip ||= (env['action_dispatch.remote_ip'] || super).to_s
    end
  end

  # Normalised email from an auth request body, used to throttle per-account
  # as well as per-IP — an attacker on a rotating IP pool still can't hammer
  # one account.
  #
  # Rack::Request#params only decodes query strings and form-encoded bodies,
  # and the SPA and CLI both post JSON, so the JSON body is parsed by hand
  # here. The body is rewound afterwards so Rails still sees it.
  def self.auth_email(req)
    email = req.params['email']

    if email.blank? && req.media_type == 'application/json'
      body = req.body.read
      req.body.rewind
      parsed = JSON.parse(body)
      email = parsed['email'] if parsed.is_a?(Hash)
    end

    email.to_s.strip.downcase.presence
  rescue StandardError
    # Malformed or unreadable body — nothing to key on, so let the per-IP
    # limits carry it rather than blowing up the request.
    nil
  end

  def self.auth_path?(req, suffix)
    req.post? && req.path == "/api/v1/auth/#{suffix}"
  end

  ### Login — password guessing ###

  # Broad per-IP ceiling: normal use is a handful of attempts.
  throttle('login/ip', limit: 20, period: 1.minute) do |req|
    req.ip if auth_path?(req, 'login')
  end

  # Tighter per-account limit, so a distributed attempt against one known
  # email address still runs out of guesses.
  throttle('login/email', limit: 10, period: 20.minutes) do |req|
    auth_email(req) if auth_path?(req, 'login')
  end

  ### Signup — account-creation / mail abuse ###

  throttle('signup/ip', limit: 5, period: 1.hour) do |req|
    req.ip if auth_path?(req, 'signup')
  end

  ### Password reset request — mail abuse, and mailbox spamming a victim ###

  throttle('password_reset_request/ip', limit: 5, period: 1.hour) do |req|
    req.ip if auth_path?(req, 'request_password_reset')
  end

  throttle('password_reset_request/email', limit: 3, period: 1.hour) do |req|
    auth_email(req) if auth_path?(req, 'request_password_reset')
  end

  ### Token submission — brute-forcing a verification / reset token ###
  #
  # The tokens are 32 bytes of SecureRandom, so guessing is hopeless anyway;
  # this mainly stops someone burning our CPU and log volume trying.

  throttle('auth_token/ip', limit: 30, period: 1.hour) do |req|
    req.ip if auth_path?(req, 'verify') ||
              auth_path?(req, 'reset_password') ||
              (req.post? && req.path == '/reset_password')
  end

  # JSON error body matching the rest of the API, plus the standard
  # Retry-After header so a client can back off sensibly.
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data'] || {}
    retry_after = (match_data[:period] || 60).to_i

    [
      429,
      { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
      [{ error: 'Too many requests — please wait a moment and try again.' }.to_json]
    ]
  end
end

# Log throttled requests so abuse is visible in the container logs.
ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn(
    "[rack-attack] throttled #{req.env['rack.attack.matched']} " \
    "ip=#{req.ip} path=#{req.path}"
  )
end
