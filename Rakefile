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

task :default do
  Rake::Task['rubocop'].execute
end
