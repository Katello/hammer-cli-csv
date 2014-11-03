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

#
# -= Locations CSV =-
#
# Columns
#   Name
#     - Name of the location.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "location%d" -> "location1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Parent
#     - Parent location
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class LocationsCommand < BaseCommand
      command_name 'locations'
      desc         'import or export locations'

      PARENT = 'Parent Location'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, PARENT]
          @api.resource(:locations).call(:index, {:per_page => 999999})['results'].each do |location|
            csv << [location['name'], 1, '']
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:locations).call(:index, {:per_page => 999999})['results'].each do |location|
          @existing[location['name']] = location['id'] if location
        end

        thread_import do |line|
          create_locations_from_csv(line)
        end
      end

      def create_locations_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          location_id = @existing[name]
          if !location_id
            print "Creating location '#{name}'... " if option_verbose?
            @api.resource(:locations).call(:create, {
                                             'location' => {
                                               'name' => name,
                                               'parent_id' => foreman_location(:name => line[PARENT])
                                             }
                                           })
          else
            print "Updating location '#{name}'... " if option_verbose?
            @api.resource(:locations).call(:update, {
                                             'id' => location_id,
                                             'location' => {
                                               'parent_id' => foreman_location(:name => line[PARENT])
                                             }
                                           })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
