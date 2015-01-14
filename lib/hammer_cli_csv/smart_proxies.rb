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

module HammerCLICsv
  class CsvCommand
    class SmartProxiesCommand < BaseCommand
      command_name 'smart-proxies'
      desc 'import or export smart proxies'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      URL = 'URL'
      LIFECYCLE_ENVIRONMENTS = 'Lifecycle Environments'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, URL, LIFECYCLE_ENVIRONMENTS]
          @api.resource(:smart_proxies).call(:index, {:per_page => 999999})['results'].each do |smart_proxy|
            smart_proxy = @api.resource(:smart_proxies).call(:show, {'id' => smart_proxy['id']})
            name = smart_proxy['name']
            count = 1
            organizations = export_column(smart_proxy, 'organizations', 'name')
            locations = export_column(smart_proxy, 'locations', 'name')
            url = smart_proxy['url']
            csv << [name, count, organizations, locations, url]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:smart_proxies).call(:index, {:per_page => 999999})['results'].each do |smart_proxy|
          @existing[smart_proxy['url']] = smart_proxy['id'] if smart_proxy
        end

        thread_import do |line|
          create_smart_proxies_from_csv(line)
        end
      end

      def create_smart_proxies_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? line[URL]
            print "Creating smart proxy '#{name}'..." if option_verbose?
            id = @api.resource(:smart_proxies).call(:create, {
                'smart_proxy' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['id']
          else
            print "Updating smart proxy '#{name}'..." if option_verbose?
            id = @api.resource(:smart_proxies).call(:update, {
                'id' => @existing[name],
                'smart_proxy' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['smart_proxy']['id']
          end

          # Update associated resources
          associate_organizations(id, line[ORGANIZATIONS], 'smart_proxy')
          associate_locations(id, line[LOCATIONS], 'smart_proxy')

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
