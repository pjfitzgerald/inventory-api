require 'thor'
require 'json'

require_relative 'inventory_cli/client'
require_relative 'inventory_cli/formatters'
require_relative 'inventory_cli/token_store'

module InventoryCLI
  # Shared Thor base: friendly exit codes and uniform error handling.
  class BaseCommand < Thor
    def self.exit_on_failure?
      true
    end

    def self.dispatch(command, given_args, given_opts, config)
      super
    rescue Client::Error => e
      warn e.message
      exit 1
    rescue Errno::ECONNREFUSED => e
      url = ENV['INVENTORY_API_URL'] || 'http://localhost:3001/api/v1'
      warn "Cannot reach API at #{url} (#{e.message}). Is the Rails server running?"
      exit 1
    end
  end

  # `inventory auth ...` — authentication commands.
  class Auth < BaseCommand
    # Accept the hyphenated forms shown in `desc` as well as the method names.
    map 'request-reset' => :request_reset
    map 'reset-password' => :reset_password

    desc 'login', 'Log in and store an auth token'
    option :email, type: :string, required: true
    option :password, type: :string, required: true
    def login
      result = client.login(email: options[:email], password: options[:password])
      TokenStore.write(result['token'])
      warn "Logged in as #{result.dig('user', 'email')}. Token saved to #{TokenStore.path}."
    end

    desc 'logout', 'Discard the stored auth token'
    def logout
      TokenStore.clear
      warn 'Logged out.'
    end

    desc 'signup', 'Create a new account'
    option :email, type: :string, required: true
    option :password, type: :string, required: true
    option :name, type: :string
    def signup
      result = client.signup(email: options[:email], password: options[:password], name: options[:name])
      warn(result['message'] || 'Account created.')
      if (token = result['verification_token'])
        warn "Verify with: inventory auth verify --token #{token}"
      end
      puts JSON.pretty_generate(result)
    end

    desc 'verify', 'Verify an email address with a token'
    option :token, type: :string, required: true
    def verify
      result = client.verify(options[:token])
      TokenStore.write(result['token']) if result['token']
      warn(result['message'] || 'Email verified.')
      warn "Logged in as #{result.dig('user', 'email')}."
    end

    desc 'request-reset', 'Request a password-reset email'
    option :email, type: :string, required: true
    def request_reset
      result = client.request_password_reset(options[:email])
      warn(result['message'] || 'If that email has an account, a reset link has been sent.')
      if (token = result['reset_token'])
        warn "Reset with: inventory auth reset-password --token #{token} --password <new-password>"
      end
    end

    desc 'reset-password', 'Set a new password using a reset token'
    option :token, type: :string, required: true
    option :password, type: :string, required: true
    def reset_password
      result = client.reset_password(token: options[:token], password: options[:password])
      TokenStore.write(result['token']) if result['token']
      warn(result['message'] || 'Password updated.')
      warn "Logged in as #{result.dig('user', 'email')}." if result.dig('user', 'email')
    end

    desc 'whoami', 'Show the currently authenticated user'
    def whoami
      puts JSON.pretty_generate(client.me['user'])
    end

    private

    def client
      @client ||= Client.new
    end
  end

  # `inventory ...` — item commands.
  class CLI < BaseCommand
    class_option :format, type: :string, default: 'json', enum: %w[json table],
                          desc: 'Output format'
    class_option :url, type: :string,
                       desc: "API base URL (default: $INVENTORY_API_URL or http://localhost:3001/api/v1)"

    desc 'auth SUBCOMMAND', 'Authentication: login, logout, signup, verify, whoami'
    subcommand 'auth', Auth

    desc 'list', 'List items, optionally filtered by --query'
    option :query, type: :string, desc: 'Search across name, category, tags, current_location'
    def list
      items = client.list(query: options[:query])
      Formatters.render(items, format: options[:format])
    end

    desc 'show ID', 'Show a single item'
    def show(id)
      item = client.show(id)
      Formatters.render(item, format: options[:format])
    end

    desc 'create', 'Create a new item (requires --name)'
    option :name, type: :string, required: true
    option :quantity, type: :numeric
    option :category, type: :string
    option :current_location, type: :string
    option :intended_location, type: :string
    option :weight, type: :numeric
    option :owner, type: :string
    option :notes, type: :string
    option :location_notes, type: :string
    option :status, type: :string, enum: %w[Keep Sell Discard]
    option :tags, type: :array, desc: 'Tags, e.g. --tags=cars books'
    option :field, type: :hash, desc: 'Custom fields, e.g. --field color:red size:L'
    def create
      item = client.create(build_attrs(options))
      Formatters.render(item, format: options[:format])
    end

    desc 'update ID', 'Update an item'
    option :name, type: :string
    option :quantity, type: :numeric
    option :category, type: :string
    option :current_location, type: :string
    option :intended_location, type: :string
    option :weight, type: :numeric
    option :owner, type: :string
    option :notes, type: :string
    option :location_notes, type: :string
    option :status, type: :string, enum: %w[Keep Sell Discard]
    option :tags, type: :array
    option :field, type: :hash
    def update(id)
      attrs = build_attrs(options)
      if attrs.empty?
        warn 'Nothing to update — pass at least one field.'
        exit 1
      end
      item = client.update(id, attrs)
      Formatters.render(item, format: options[:format])
    end

    desc 'delete ID', 'Delete an item'
    def delete(id)
      client.destroy(id)
      warn "Deleted item #{id}"
    end

    private

    def client
      require_auth!
      @client ||= Client.new(**(options[:url] ? { base_url: options[:url] } : {}))
    end

    def require_auth!
      return if TokenStore.read

      warn 'Not authenticated — run `inventory auth login` first.'
      exit 1
    end

    PARAM_KEYS = %w[name quantity category current_location intended_location
                    weight owner notes location_notes status tags].freeze

    def build_attrs(opts)
      attrs = PARAM_KEYS.each_with_object({}) do |key, h|
        h[key] = opts[key] if opts.key?(key)
      end
      attrs['custom_fields'] = opts[:field] if opts[:field]
      attrs
    end
  end
end
