# frozen_string_literal: true

desc "Check that all autoloaded files in rack.rb exist"
task :check_autoloads do
  rack_rb_path = File.expand_path('../../lib/rack.rb', __FILE__)
  rack_rb_content = File.read(rack_rb_path)

  autoload_paths = rack_rb_content.scan(/autoload\s+:\w+,\s*"([^"]+)"/).flatten

  lib_dir = File.expand_path('../../lib', __FILE__)
  missing_files = []

  autoload_paths.each do |relative_path|
    full_path = File.join(lib_dir, "#{relative_path}.rb")
    unless File.exist?(full_path)
      missing_files << full_path
    end
  end

  if missing_files.empty?
    puts "All autoloaded files exist. (#{autoload_paths.size} files checked)"
  else
    puts "Missing autoloaded files (#{missing_files.size}):"
    missing_files.each { |f| puts "  - #{f}" }
    abort
  end
end