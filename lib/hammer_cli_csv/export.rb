# Copyright 2013-2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.


module HammerCLICsv
  class CsvCommand
    class ExportCommand < HammerCLI::Apipie::Command
      command_name 'export'
      desc         'export into directory'

      option %w(-v --verbose), :flag, 'be verbose'
      option %w(--threads), 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
      option '--dir', 'DIRECTORY', 'directory to import from'

      RESOURCES = %w(
        organizations locations puppet_environments operating_systems
        domains architectures partition_tables lifecycle_environments host_collections
        provisioning_templates
        subscriptions activation_keys hosts content_hosts reports roles users
      )
      RESOURCES.each do |resource|
        dashed = resource.sub('_', '-')
        option "--#{dashed}", 'FILE', "csv file for #{dashed}"
      end

      def execute
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

        @server_status = check_server_status(@server, @username, @password)

        if @server_status['release'] == 'Headpin'
          @headpin = HeadpinApi.new({
                                      :server => @server,
                                      :username => @username,
                                      :password => @password
                                    })
          skipped_resources = %w( locations puppet_environments operating_systems
                                  domains architectures partition_tables lifecycle_environments
                                  provisioning_templates
                                  hosts reports )
          skipped_resources += %w( subscriptions content_hosts roles users )  # TODO: not implemented yet
        else
          @api = ApipieBindings::API.new({
                                           :uri => @server,
                                           :username => @username,
                                           :password => @password,
                                           :api_version => 2
                                         })
          skipped_resources = []
        end

        # Swing the hammers
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
        args += %W( csv #{resource.sub('_', '-')} --csv-export --csv-file #{options_file} )
        args << '-v' if option_verbose?
        args += %W( --threads #{option_threads} )
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
