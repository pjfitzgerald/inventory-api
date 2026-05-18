require 'json'
require 'net/http'
require 'uri'

require_relative 'token_store'

module InventoryCLI
  class Client
    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    def initialize(base_url: ENV.fetch('INVENTORY_API_URL', 'http://localhost:3001/api/v1'),
                   token: TokenStore.read)
      @base_url = base_url.chomp('/')
      @token = token
    end

    # --- items ---

    def list(query: nil)
      path = '/items'
      path += "?query=#{URI.encode_www_form_component(query)}" if query
      request(Net::HTTP::Get, path)
    end

    def show(id)
      request(Net::HTTP::Get, "/items/#{id}")
    end

    def create(attrs)
      request(Net::HTTP::Post, '/items', body: { item: attrs })
    end

    def update(id, attrs)
      request(Net::HTTP::Patch, "/items/#{id}", body: { item: attrs })
    end

    def destroy(id)
      request(Net::HTTP::Delete, "/items/#{id}")
    end

    # --- auth ---

    def signup(email:, password:, name: nil)
      request(Net::HTTP::Post, '/auth/signup',
              body: { email: email, password: password, name: name }.compact)
    end

    def login(email:, password:)
      request(Net::HTTP::Post, '/auth/login', body: { email: email, password: password })
    end

    def verify(token)
      request(Net::HTTP::Post, '/auth/verify', body: { token: token })
    end

    def request_password_reset(email)
      request(Net::HTTP::Post, '/auth/request_password_reset', body: { email: email })
    end

    def reset_password(token:, password:)
      request(Net::HTTP::Post, '/auth/reset_password',
              body: { token: token, password: password })
    end

    def me
      request(Net::HTTP::Get, '/auth/me')
    end

    private

    def request(method_class, path, body: nil)
      uri = URI("#{@base_url}#{path}")
      req = method_class.new(uri)
      req['Content-Type'] = 'application/json'
      req['Accept'] = 'application/json'
      req['Authorization'] = "Bearer #{@token}" if @token
      req.body = JSON.generate(body) if body

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end

      parsed = res.body.to_s.empty? ? nil : (JSON.parse(res.body) rescue res.body)
      code = res.code.to_i

      return parsed if code >= 200 && code < 300

      raise Error.new(error_message(code, parsed), status: code, body: parsed)
    end

    def error_message(code, parsed)
      case code
      when 401
        parsed.is_a?(Hash) && parsed['error'] ? parsed['error'] : 'Not authenticated'
      when 404
        'Not found'
      when 422
        "Validation failed (#{validation_details(parsed)})"
      else
        summary = if parsed.is_a?(Hash)
                    parsed['error'] || parsed['message'] || parsed.keys.first(3).inspect
                  else
                    parsed.to_s
                  end
        "API #{code} #{summary}"
      end
    end

    def validation_details(parsed)
      return parsed.to_s unless parsed.is_a?(Hash)
      return Array(parsed['errors']).join('; ') if parsed['errors']

      parsed.map { |field, msgs| "#{field}: #{Array(msgs).join(', ')}" }.join('; ')
    end
  end
end
