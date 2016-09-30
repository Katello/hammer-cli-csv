module HammerCLICsv
  module Utils
    module Config
      def credentials
        @credentials ||= HammerCLIForeman::BasicCredentials.new(
          :username => (HammerCLI::Settings.get(:_params, :username) || ENV['FOREMAN_USERNAME'] || HammerCLI::Settings.get(:foreman, :username)),
          :password => (HammerCLI::Settings.get(:_params, :password) || ENV['FOREMAN_PASSWORD'] || HammerCLI::Settings.get(:foreman, :password))
        )
        @credentials
      end

      def resource_config
        config = {}
        config[:uri] = HammerCLI::Settings.get(:_params, :host) || HammerCLI::Settings.get(:foreman, :host)
        config[:credentials] = credentials
        config[:logger] = Logging.logger['API']
        config[:api_version] = 2
        config[:follow_redirects] = HammerCLI::Settings.get(:foreman, :follow_redirects) || :never
        config[:aggressive_cache_checking] = HammerCLI::Settings.get(:foreman, :refresh_cache) || false
        config[:headers] = { "Accept-Language" => HammerCLI::I18n.locale }
        config[:language] = HammerCLI::I18n.locale
        config[:timeout] = HammerCLI::Settings.get(:foreman, :request_timeout)
        config[:timeout] = -1 if config[:timeout] && config[:timeout].to_i < 0
        config[:apidoc_authenticated] = false

        @username = config[:credentials].username
        @password = config[:credentials].password
        @server = config[:uri]
        config
      end

      def api_connection
        connection = HammerCLI::Connection.create(
          'csv',
          HammerCLI::Apipie::Command.resource_config.merge(resource_config),
          HammerCLI::Apipie::Command.connection_options
        )
        connection.api
      end
    end
  end
end
