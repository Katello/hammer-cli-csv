require 'simplecov'
require 'pathname'
require 'stringio'
require 'tempfile'
require 'fileutils'

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

require './test/test_runner'

require 'hammer_cli'
require 'hammer_cli_foreman/commands'

VCR.insert_cassette("apipie", {})
require 'hammer_cli_csv'
require 'hammer_cli_foreman'
require 'hammer_cli_katello'
VCR.eject_cassette

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
  if HammerCLI.context[:api_connection]
    HammerCLI.context[:api_connection].drop_all
  else
    HammerCLI::Connection.drop_all
    HammerCLIForeman.clear_credentials
  end
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

def host_delete(hostname)
  stdout,stderr = capture {
    hammer.run(%W(host list --search #{hostname}))
  }
  lines = stdout.split("\n")
  if lines.length == 5
    id = lines[3].split(" ")[0]
    stdout,stderr = capture {
      hammer.run(%W(host delete --id #{id}))
    }
  end
end

def content_view_delete(name, environments="Library")
  org = 'Test Corporation'
  id = nil
  stdout,stderr = capture {
    hammer.run(%W(content-view list --search #{name}))
  }
  lines = stdout.split("\n")
  if lines.length == 5
    id = lines[3].split(" ")[0]
  end

  if id
    stdout,stderr = capture {
      hammer.run(%W(content-view remove --id #{id} --organization #{org} --environments #{environments}))
    }

    stdout,stderr = capture {
      hammer.run(%W(content-view delete --id #{id}))
    }
  end
end

def content_view_filter_delete(org, cv, name)
  id = nil
  stdout,stderr = capture {
    hammer.run(%W(content-view filter list --search name=#{name} --content-view #{cv} --organization #{org}))
  }
  lines = stdout.split("\n")
  if lines.length == 5
    id = lines[3].split(" ")[0]
  end

  if id
    stdout,stderr = capture {
      hammer.run(%W(content-view filter delete --id #{id}))
    }
  end
end

require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require File.join(File.dirname(__FILE__), 'helpers/command')
require File.join(File.dirname(__FILE__), 'helpers/resource_disabled')
