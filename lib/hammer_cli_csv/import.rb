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
    class ImportCommand < HammerCLI::Apipie::Command
      command_name 'import'
      desc         'import by directory'

      option %w(-v --verbose), :flag, 'be verbose'
      option %w(--threads), 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
      option '--dir', 'DIRECTORY', 'directory to import from'

      RESOURCES = %w( organizations locations puppet_environments operating_systems
                      domains architectures partition_tables lifecycle_environments host_collections
                      provisioning_templates
                      subscriptions products content_views content_view_filters activation_keys
                      hosts content_hosts reports roles users )
      RESOURCES.each do |resource|
        dashed = resource.sub('_', '-')
        option "--#{dashed}", 'FILE', "csv file for #{dashed}"
      end

      def execute
        @api = ApipieBindings::API.new({:uri => get_option(:host), :username => get_option(:username),
                                        :password => get_option(:password), :api_version => 2})

        # Swing the hammers
        RESOURCES.each do |resource|
          hammer_resource(resource)
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
        options_file = self.send("option_#{resource}") || "#{option_dir}/#{resource.sub('_', '-')}.csv"
        if !File.exists? options_file
          return if option_dir
          raise "File for #{resource} '#{options_file}' does not exist"
        end

        args = %W( csv #{resource.sub('_', '-')} --csv-file #{options_file} )
        args << '-v' if option_verbose?
        args += %W( --threads #{option_threads} )
        hammer.run(args)
      end

      private

      def get_option(name)
        HammerCLI::Settings.settings[:_params][name] ||
          HammerCLI::Settings.get(:csv, name) ||
          HammerCLI::Settings.get(:katello, name) ||
          HammerCLI::Settings.get(:foreman, name)
      end
    end
  end
end
