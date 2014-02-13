require 'simplecov'
require 'pathname'

SimpleCov.use_merging true
SimpleCov.start do
  command_name 'MiniTest'
  add_filter 'test'
end
SimpleCov.root Pathname.new(File.dirname(__FILE__) + "../../../")


require 'minitest/autorun'
require 'minitest/spec'
require "minitest-spec-context"
require "mocha/setup"

require 'hammer_cli_csv'
require 'hammer_cli_katello'
require 'hammer_cli_foreman'

def ctx
  {
    :adapter => :csv,
    :interactive => false
  }
end

def hammer
  HammerCLI::MainCommand.new("", ctx)
end

def capture
  old_stdout = $stdout
  old_stderr = $stderr
  $stdout = stdout = StringIO.new
  $stderr = stderr = StringIO.new
  yield
  [stdout.string, stderr.string]
ensure
  $stdout = old_stdout
  $stderr = old_stderr
end

def set_user(username, password='changeme')
  HammerCLI::Settings.load({
                             :_params => {
                               :username => username,
                               :password => password,
                               :interactive => false
                             }})
end


#require File.join(File.dirname(__FILE__), 'test_output_adapter')
require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require File.join(File.dirname(__FILE__), 'helpers/command')
require File.join(File.dirname(__FILE__), 'helpers/resource_disabled')
