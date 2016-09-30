module HammerCLICsv
  class CsvCommand
    class ExportCommand < HammerCLI::Apipie::Command
      include ::HammerCLICsv::Utils::Config

      command_name 'export'
      desc         'export into directory'

      def self.supported?
        true
      end

      option %w(-v --verbose), :flag, _('be verbose')
      option %w(--threads), 'THREAD_COUNT', _('Number of threads to hammer with'),
             :default => 1, :hidden => true
      option '--dir', 'DIRECTORY', _('directory to export to')
      option %w(--organization), 'ORGANIZATION', _('Only process organization matching this name')

      RESOURCES = %w(
        settings organizations locations puppet_environments operating_systems
        domains architectures partition_tables lifecycle_environments host_collections
        provisioning_templates
        subscriptions activation_keys hosts content_hosts reports roles users
      )
      SUPPORTED_RESOURCES = %w(
        settings
      )
      RESOURCES.each do |resource|
        dashed = resource.sub('_', '-')
        option "--#{dashed}", 'FILE', "csv file for #{dashed}",
               :hidden => !SUPPORTED_RESOURCES.include?(resource)
      end

      def execute
        @api = api_connection
        skipped_resources = (RESOURCES - SUPPORTED_RESOURCES)

        (RESOURCES - skipped_resources).each do |resource|
          hammer_resource(resource)
        end

        HammerCLI::EX_OK
      end

      def hammer(context = nil)
        context ||= {
          :interactive => false,
          :username => @username,
          :password => @password
        }

        HammerCLI::MainCommand.new('', context)
      end

      def hammer_resource(resource)
        return if !self.send("option_#{resource}") && !option_dir
        options_file = self.send("option_#{resource}") || "#{option_dir}/#{resource.sub('_', '-')}.csv"
        args = []
        args += %W( --server #{@server} ) if @server
        args += %W( csv #{resource.sub('_', '-')} --export --file #{options_file} )
        args << '-v' if option_verbose?
        args += %W( --organization #{option_organization} ) if option_organization
        args += %W( --threads #{option_threads} ) if option_threads
        puts "Exporting '#{args.join(' ')}'" if option_verbose?
        hammer.run(args)
      end

      def check_server_status(server, username, password)
        url = "#{server}/api/status"
        uri = URI(url)
        nethttp = Net::HTTP.new(uri.host, uri.port)
        nethttp.use_ssl = uri.scheme == 'https'
        nethttp.verify_mode = OpenSSL::SSL::VERIFY_NONE
        server_status = nethttp.start do |http|
          request = Net::HTTP::Get.new uri.request_uri
          request.basic_auth(username, password)
          response = http.request(request)
          JSON.parse(response.body)
        end

        server_status
      end
    end
  end
end
