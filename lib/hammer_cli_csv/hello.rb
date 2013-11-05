require 'hammer_cli'
require 'katello_api'

module HammerCLICsv

  class HelloCommand < HammerCLI::AbstractCommand

    def initialize(*args)
      init_options = { :base_url => HammerCLI::Settings.get(:katello, :host),
                       :username => HammerCLI::Settings.get(:katello, :username),
                       :password => HammerCLI::Settings.get(:katello, :password) }
      @ping = KatelloApi::Resources::Ping.new(init_options)
    end

    def execute
      # TODO hammer has output adapters; use them
      puts @ping.index[0]
      HammerCLI::EX_OK
    end

  end

  HammerCLI::MainCommand.subcommand("hello", "ping the katello server", HammerCLICsv::HelloCommand)
end
