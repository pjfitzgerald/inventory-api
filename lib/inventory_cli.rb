require 'thor'
require 'json'

require_relative 'inventory_cli/client'
require_relative 'inventory_cli/formatters'

module InventoryCLI
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    def self.banner(command, namespace = nil, subcommand = false)
      "inventory #{command.usage}"
    end

    class_option :format, type: :string, default: 'json', enum: %w[json table],
                          desc: 'Output format'
    class_option :url, type: :string,
                       desc: "API base URL (default: $INVENTORY_API_URL or http://localhost:3001/api/v1)"

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
    option :field, type: :hash, desc: 'Custom fields, e.g. --field color=red size=L'
    def create
      attrs = build_attrs(options)
      item = client.create(attrs)
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
      @client ||= Client.new(**(options[:url] ? { base_url: options[:url] } : {}))
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

    def self.dispatch(command, given_args, given_opts, config)
      super
    rescue Client::Error => e
      warn e.message
      exit 1
    rescue Errno::ECONNREFUSED => e
      warn "Cannot reach API at #{ENV['INVENTORY_API_URL'] || 'http://localhost:3001/api/v1'} (#{e.message}). Is the Rails server running?"
      exit 1
    end
  end
end
