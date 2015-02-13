require 'simplecov'
require 'pathname'
require 'stringio'
require 'tempfile'

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

require 'hammer_cli'
require 'hammer_cli_foreman/commands'

HammerCLI::Settings.load_from_file 'test/config.yml'

require 'hammer_cli_csv'
require 'hammer_cli_foreman'
require 'hammer_cli_katello'

module HammerCLIForeman
  def self.clear_credentials
    @credentials = nil
  end
end

def hammer(context=nil)
  HammerCLI::MainCommand.new("", context || HammerCLI::Settings.dump)
end

require 'apipie-bindings'
def api
  @server = HammerCLI::Settings.settings[:_params][:host] ||
    HammerCLI::Settings.get(:csv, :host) ||
    HammerCLI::Settings.get(:katello, :host) ||
    HammerCLI::Settings.get(:foreman, :host)
  @username = HammerCLI::Settings.settings[:_params][:username] ||
    HammerCLI::Settings.get(:csv, :username) ||
    HammerCLI::Settings.get(:katello, :username) ||
    HammerCLI::Settings.get(:foreman, :username)
  @password = HammerCLI::Settings.settings[:_params][:password] ||
    HammerCLI::Settings.get(:csv, :password) ||
    HammerCLI::Settings.get(:katello, :password) ||
    HammerCLI::Settings.get(:foreman, :password)
  @api = ApipieBindings::API.new({
                                   :uri => @server,
                                   :username => @username,
                                   :password => @password,
                                   :api_version => 2
                                 })
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
  HammerCLI::Connection.drop_all
  HammerCLIForeman.clear_credentials
  HammerCLI::Settings.load({
                               :_params => {
                                   :username => username,
                                   :password => password
                               },
                               :foreman => {
                                   :username => username,
                                   :password => password
                               },
                               :csv => {
                                   :username => username,
                                   :password => password
                               }
                           })
end

require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require File.join(File.dirname(__FILE__), 'helpers/command')
require File.join(File.dirname(__FILE__), 'helpers/resource_disabled')
