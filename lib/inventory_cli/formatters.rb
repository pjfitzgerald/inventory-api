require 'json'

module InventoryCLI
  module Formatters
    module_function

    def render(data, format:)
      case format
      when 'json' then puts JSON.pretty_generate(data)
      when 'table' then puts table(data)
      else raise ArgumentError, "unknown format: #{format}"
      end
    end

    def table(data)
      records = data.is_a?(Array) ? data : [data]
      return '(empty)' if records.empty?

      cols = %w[id name quantity category status tags current_location]
      rows = records.map { |r| cols.map { |c| format_cell(r[c]) } }
      widths = cols.each_with_index.map do |c, i|
        ([c.length] + rows.map { |row| row[i].length }).max
      end

      header = cols.each_with_index.map { |c, i| c.ljust(widths[i]) }.join('  ')
      sep = widths.map { |w| '-' * w }.join('  ')
      body = rows.map { |row| row.each_with_index.map { |v, i| v.ljust(widths[i]) }.join('  ') }

      [header, sep, *body].join("\n")
    end

    def format_cell(value)
      case value
      when nil then ''
      when Array then value.join(',')
      when Hash then value.map { |k, v| "#{k}=#{v}" }.join(',')
      else value.to_s
      end
    end
  end
end
