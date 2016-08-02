#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rake/testtask'

def clear_cassettes
  `rm -rf test/fixtures/vcr_cassettes/*.yml`
  `rm -rf test/fixtures/vcr_cassettes/extensions/*.yml`
  `rm -rf test/fixtures/vcr_cassettes/support/*.yml`
  print "Cassettes cleared\n"
end

# Rake::TestTask.new do |t|
#   t.libs << "lib"
#   t.test_files = Dir['test/setup_test.rb'] + Dir.glob('test/**/*_test.rb')
#   t.verbose = true
# end

namespace :test do
  [:resources].each do |task_name|
    desc "Runs the #{task_name} tests"
    task task_name do
      options = {}

      options[:mode]      = ENV['mode'] || 'none'
      options[:test_name] = ENV['test']
      options[:auth_type] = ENV['auth_type']
      options[:logging]   = ENV['logging']

      if !%w(new_episodes all none once).include?(options[:mode])
        puts 'Invalid test mode'
      else
        require './test/test_runner'

        test_runner = CsvMiniTestRunner.new

        if options[:test_name]
          puts "Running tests for: #{options[:test_name]}"
        else
          puts "Running tests for: #{task_name}"
        end

        clear_cassettes if options[:mode] == 'all' && options[:test_name].nil? && ENV['record'] != 'false'
        test_runner.run_tests(task_name, options)
      end
    end
  end
end


begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue
  puts "Rubocop not loaded"
end

namespace :gettext do
  desc "Update pot file"
  task :find do
    require "hammer_cli_csv/version"
    require "hammer_cli_csv/i18n"
    require 'gettext/tools'

    domain = HammerCLICsv::I18n::LocaleDomain.new
    GetText.update_pofiles(domain.domain_name, domain.translated_files, "#{domain.domain_name} #{HammerCLICsv.version}", :po_root => domain.locale_dir)
  end
end

desc 'Clears out all cassette files'
task :clear_cassettes do
  clear_cassettes
end

desc 'Runs all tests'
task :test do
  Rake::Task['test:resources'].invoke
end

task :default do
  Rake::Task['rubocop'].execute
  Rake::Task['test'].execute
end
