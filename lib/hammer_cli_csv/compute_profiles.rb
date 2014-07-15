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

require 'hammer_cli'
require 'json'
require 'csv'

# TODO: waiting for https://github.com/theforeman/foreman/pull/1326

module HammerCLICsv
  class CsvCommand
    class ComputeProfilesCommand < BaseCommand
      command_name 'compute-profiles'
      desc 'import or export compute profiles'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      DESCRIPTION = 'Description'
      PROVIDER = 'Provider'
      URL = 'URL'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, DESCRIPTION, PROVIDER, URL]
          @api.resource(:compute_profiles).call(:index, {:per_page => 999999})['results'].each do |compute_profile|
            puts compute_profile
            compute_profile = @api.resource(:compute_profiles).call(:show, {'id' => compute_profile['id']})
            name = compute_profile['name']
            count = 1
            organizations = export_column(compute_profile, 'organizations', 'name')
            locations = export_column(compute_profile, 'locations', 'name')
            description = compute_profile['description']
            provider = compute_profile['provider']
            url = compute_profile['url']
            csv << [name, count, organizations, locations, description, provider, url]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:compute_profiles).call(:index, {:per_page => 999999})['results'].each do |compute_profile|
          @existing[compute_profile['name']] = compute_profile['id'] if compute_profile
        end

        thread_import do |line|
          create_compute_profiles_from_csv(line)
        end
      end

      def create_compute_profiles_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating compute profile '#{name}'..." if option_verbose?
            id = @api.resource(:compute_profiles)
              .call(:create, {
                      'compute_profile' => {
                        'name' => name,
                        'url' => line[URL]
                      }
                    })['id']
          else
            print "Updating compute profile '#{name}'..." if option_verbose?
            id = @api.resource(:compute_profiles)
              .call(:update, {
                      'id' => @existing[name],
                      'compute_profile' => {
                        'name' => name,
                        'url' => line[URL]
                      }
                    })['compute_profile']['id']
          end

          # Update associated profiles
          associate_organizations(id, line[ORGANIZATIONS], 'compute_profile')
          associate_locations(id, line[LOCATIONS], 'compute_profile')

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
