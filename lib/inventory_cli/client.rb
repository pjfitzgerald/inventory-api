require 'json'
require 'net/http'
require 'uri'

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

    def initialize(base_url: ENV.fetch('INVENTORY_API_URL', 'http://localhost:3001/api/v1'))
      @base_url = base_url.chomp('/')
    end

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

    private

    def request(method_class, path, body: nil)
      uri = URI("#{@base_url}#{path}")
      req = method_class.new(uri)
      req['Content-Type'] = 'application/json'
      req['Accept'] = 'application/json'
      req.body = JSON.generate(body) if body

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end

      parsed = res.body.to_s.empty? ? nil : JSON.parse(res.body) rescue res.body
      code = res.code.to_i

      return parsed if code >= 200 && code < 300

      msg =
        case code
        when 404 then 'Not found'
        when 422
          errs = parsed.is_a?(Hash) ? parsed.map { |k, v| "#{k}: #{Array(v).join(', ')}" }.join('; ') : parsed.to_s
          "Validation failed (#{errs})"
        else
          summary = parsed.is_a?(Hash) ? (parsed['error'] || parsed['message'] || parsed.keys.first(3).inspect) : parsed.to_s
          "API #{code} #{summary}"
        end
      raise Error.new(msg, status: code, body: parsed)
    end
  end
end
