require 'fileutils'

module InventoryCLI
  # Persists the auth token at ~/.config/inventory/token (mode 0600).
  # The INVENTORY_API_TOKEN env var, when set, overrides the stored file.
  module TokenStore
    module_function

    def path
      base = ENV['XDG_CONFIG_HOME']
      base = File.expand_path('~/.config') if base.to_s.empty?
      File.join(base, 'inventory', 'token')
    end

    def read
      env = ENV['INVENTORY_API_TOKEN']
      return env unless env.to_s.empty?
      return nil unless File.exist?(path)

      content = File.read(path).strip
      content.empty? ? nil : content
    end

    def write(token)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, token)
      File.chmod(0o600, path)
    end

    def clear
      File.delete(path) if File.exist?(path)
    end
  end
end
