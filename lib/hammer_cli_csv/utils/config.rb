module HammerCLICsv
  module Utils
    module Config
      def api_connection
        @server ||= HammerCLI::Settings.get(:_params, :host) || HammerCLI::Settings.get(:foreman, :host)
        HammerCLIForeman.foreman_api_connection.api
      end
    end
  end
end
