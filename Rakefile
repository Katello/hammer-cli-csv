#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rake/testtask'

def clear_cassettes
  `rm -rf test/fixtures/vcr_cassettes/setup/*.yml`
  `rm -rf test/fixtures/vcr_cassettes/resources/*.yml`
  print "Cassettes cleared\n"
end

namespace :test do
  %w(setup resources).each do |task_name|
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

  task :setup do
    require "hammer_cli_csv/version"
    require "hammer_cli_csv/i18n"
    require 'gettext/tools/task'

    domain = HammerCLICsv::I18n::LocaleDomain.new
    GetText::Tools::Task.define do |task|
      task.package_name = domain.domain_name
      task.package_version = HammerCLICsv.version.to_s
      task.domain = domain.domain_name
      task.mo_base_directory = domain.locale_dir
      task.po_base_directory = domain.locale_dir
      task.files = domain.translated_files
    end
  end

  desc "Update pot file"
  task :find => [:setup] do
    Rake::Task["gettext:po:update"].invoke
  end
end

desc 'Clears out all cassette files'
task :clear_cassettes do
  clear_cassettes
end

desc 'Runs all tests'
task :test do
  Rake::Task['test:setup'].invoke
  Rake::Task['test:resources'].invoke
end

task :default do
  Rake::Task['rubocop'].execute
  Rake::Task['test'].execute
end
