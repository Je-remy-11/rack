# frozen_string_literal: true

require_relative 'helper'

describe "Rack autoload" do
  it "loads all constants successfully without LoadError" do
    autoloads = {
      Rack => [],
      Rack::Auth => []
    }

    rack_lib_path = File.expand_path('../lib/rack.rb', __dir__)
    current_module = Rack

    File.read(rack_lib_path).each_line do |line|
      if line =~ /^\s*module\s+Auth/
        current_module = Rack::Auth
      elsif line =~ /^\s*end/
        current_module = Rack
      elsif line =~ /^\s*autoload\s+:(\w+)/
        autoloads[current_module] << $1.to_sym
      end
    end

    # Ensure we actually parsed the file correctly
    autoloads[Rack].wont_be_empty
    autoloads[Rack::Auth].wont_be_empty

    autoloads.each do |mod, consts|
      consts.each do |const|
        begin
          # Trigger the autoload by referencing the constant
          mod.const_get(const).wont_be_nil
        rescue LoadError => e
          flunk "Failed to load #{mod}::#{const} due to LoadError: #{e.message}"
        rescue NameError => e
          flunk "Failed to load #{mod}::#{const} due to NameError: #{e.message}"
        end
      end
    end
  end
end
