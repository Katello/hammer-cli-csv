module HammerCLICsv
  module Utils
    module Config
      CONNECTION_NAME = 'csv'
      def api_connection
        HammerCLI.context[:api_connection].create(CONNECTION_NAME) do
          HammerCLIForeman::Api::Connection.new(HammerCLI::Settings, Logging.logger['API'], HammerCLI::I18n.locale)
        end
      end
    end
  end
end
