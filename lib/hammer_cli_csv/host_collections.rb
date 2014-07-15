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
# -= System Groups CSV =-
#
# Columns
#   Name
#     - System group name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "group%d" -> "group1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Org Label
#   Limit
#   Description
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class HostCollectionsCommand < BaseCommand
      command_name 'host-collections'
      desc         'import or export host collections'

      ORGANIZATION = 'Organization'
      LIMIT = 'Limit'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_csv_file, 'wb') do |csv|
          csv << [NAME, COUNT, ORGANIZATION, LIMIT, DESCRIPTION]
          @api.resource(:organizations)
            .call(:index, {
                    'per_page' => 999999
                  })['results'].each do |organization|
            @api.resource(:host_collections)
              .call(:index, {
                      'organization_id' => organization['id']
                    }).each do |hostcollection|
              puts hostcollection
              csv << [hostcollection['name'], 1, organization['id'],
                      hostcollection['max_systems'].to_i < 0 ? 'Unlimited' : sytemgroup['max_systems'],
                      hostcollection['description']]
            end
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_hostcollections_from_csv(line)
        end
      end

      def create_hostcollections_from_csv(line)
        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          @api.resource(:host_collections)
            .call(:index, {
                    'per_page' => 999999,
                    'organization_id' => foreman_organization(:name => line[ORGANIZATION])
                  })['results'].each do |hostcollection|
            @existing[line[ORGANIZATION]][hostcollection['name']] = hostcollection['id']
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing[line[ORGANIZATION]].include? name
            print "Creating system group '#{name}'..." if option_verbose?
            @api.resource(:host_collections)
              .call(:create, {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'name' => name,
                      'max_systems' => (line[LIMIT] == 'Unlimited') ? -1 : line[LIMIT],
                      'description' => line[DESCRIPTION]
                    })
          else
            print "Updating system group '#{name}'..." if option_verbose?
            @api.resource(:host_collections)
              .call(:update, {
                      'organization_id' => line[ORGANIZATION],
                      'id' => @existing[line[ORGANIZATION]][name],
                      'name' => name,
                      'max_systems' => (line[LIMIT] == 'Unlimited') ? -1 : line[LIMIT],
                      'description' => line[DESCRIPTION]
                    })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
