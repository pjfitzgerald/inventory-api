#!/usr/bin/env ruby
# CLI entry point. Bundles itself against this app's Gemfile so it works
# from any directory: `~/code/projects/inventory/api/bin/inventory list`.

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'inventory_cli'

# So Thor's generated help/usage reads "inventory", not "inventory.rb".
$PROGRAM_NAME = 'inventory'

InventoryCLI::CLI.start(ARGV)
