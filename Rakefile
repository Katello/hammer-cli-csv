require 'rake/testtask'
require 'bundler/gem_tasks'
#require 'ci/reporter/rake/minitest'

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = Dir['test/setup_test.rb'] + Dir.glob('test/**/*_test.rb')
  t.verbose = true
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


task :default do
  Rake::Task['rubocop'].execute
end
