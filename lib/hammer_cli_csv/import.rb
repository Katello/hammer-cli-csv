require 'open-uri'

module HammerCLICsv
  class CsvCommand
    class ImportCommand < HammerCLI::Apipie::Command
      command_name 'import'
      desc         'import by directory'

      def self.supported?
        true
      end

      option %w(-v --verbose), :flag, _('be verbose')
      option %w(--threads), 'THREAD_COUNT', _('Number of threads to hammer with'),
             :default => 1, :hidden => true
      option '--dir', 'DIRECTORY', _('directory to import from')
      option %w(--organization), 'ORGANIZATION', _('Only process organization matching this name')
      option %w(--prefix), 'PREFIX', _('Prefix for all name columns'),
             :hidden => true

      RESOURCES = %w(
        settings organizations locations puppet_environments operating_systems
        domains architectures partition_tables lifecycle_environments host_collections
        provisioning_templates
        subscriptions products content_views content_view_filters activation_keys
        hosts content_hosts smart_proxies compute_resources reports roles users
      )
      SUPPORTED_RESOURCES = %w(
        settings
      )
      RESOURCES.each do |resource|
        dashed = resource.gsub('_', '-')
        option "--#{dashed}", 'FILE', "csv file for #{dashed}",
               :hidden => !SUPPORTED_RESOURCES.include?(resource)
      end

      def execute
        @server = (HammerCLI::Settings.settings[:_params] &&
                   HammerCLI::Settings.settings[:_params][:host]) ||
          HammerCLI::Settings.get(:csv, :host) ||
          HammerCLI::Settings.get(:katello, :host) ||
          HammerCLI::Settings.get(:foreman, :host)
        @username = (HammerCLI::Settings.settings[:_params] &&
                     HammerCLI::Settings.settings[:_params][:username]) ||
          HammerCLI::Settings.get(:csv, :username) ||
          HammerCLI::Settings.get(:katello, :username) ||
          HammerCLI::Settings.get(:foreman, :username)
        @password = (HammerCLI::Settings.settings[:_params] &&
                     HammerCLI::Settings.settings[:_params][:password]) ||
          HammerCLI::Settings.get(:csv, :password) ||
          HammerCLI::Settings.get(:katello, :password) ||
          HammerCLI::Settings.get(:foreman, :password)
        @api = ApipieBindings::API.new({:uri => @server, :username => @username,
                                        :password => @password, :api_version => 2})

        resources_specified = RESOURCES.collect do |resource|
          resource if self.send("option_#{resource}") || ARGV.include?('--' + resource.gsub('_', '-'))
        end
        resources_specified.compact!
        RESOURCES.each do |resource|
          if resources_specified.include?(resource) || (resources_specified == [] && option_dir)
            hammer_resource(resource)
          end
        end

        HammerCLI::EX_OK
      end

      def hammer(context = nil)
        context ||= {
          :interactive => false,
          :username => 'admin', # TODO: this needs to come from config/settings
          :password => 'changeme' # TODO: this needs to come from config/settings
        }

        HammerCLI::MainCommand.new('', context)
      end

      def hammer_resource(resource)
        return if !self.send("option_#{resource}") && !option_dir
        options_file = option_dir ? "#{option_dir}/#{resource.gsub('_', '-')}.csv" :  self.send("option_#{resource}")
        unless options_file_exists? options_file
          if option_dir
            return unless SUPPORTED_RESOURCES.include?(resource)
            puts _("Skipping %{resource} because '%{options_file}' does not exist") %
              {:resource => resource, :options_file => options_file} if option_verbose?
            return
          end
          raise "File for #{resource} '#{options_file}' does not exist"
        end
        puts _("Importing %{resource} from '%{options_file}'") %
          {:resource => resource, :options_file => options_file} if option_verbose?

        args = %W( csv #{resource.gsub('_', '-')} --file #{options_file} )
        args << '-v' if option_verbose?
        args += %W( --organization #{option_organization} ) if option_organization
        args += %W( --prefix #{option_prefix} ) if option_prefix
        args += %W( --threads #{option_threads} ) if option_threads
        hammer.run(args)
      end

      private

      def options_file_exists?(options_file)
        f = open(options_file)
        f.close
        true
      rescue
        false
      end

      def get_option(name)
        HammerCLI::Settings.settings[:_params][name] ||
          HammerCLI::Settings.get(:csv, name) ||
          HammerCLI::Settings.get(:katello, name) ||
          HammerCLI::Settings.get(:foreman, name)
      end
    end
  end
end
