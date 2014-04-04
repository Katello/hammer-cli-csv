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
# -= Users CSV =-
#
# Columns
#   Name
#     - Login name of the user.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "user%d" -> "user1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Description
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class RolesCommand < BaseCommand

    ROLE = "Role"
    FILTER = "Filter"
    PERMISSIONS = "Permissions"
    ORGANIZATIONS = "Organizations"
    LOCATIONS = "Locations"

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
        csv << [NAME, COUNT, FILTER, PERMISSIONS, ORGANIZATIONS, LOCATIONS]
        @api.resource(:roles).call(:index, {'per_page' => 999999})['results'].each do |role|
          @api.resource(:filters).call(:index, {
                                'per_page' => 999999,
                                'search' => "role=\"#{role['name']}\""
                              })['results'].each do |filter|
            if filter['search'] && filter['search'] != ''
              permissions = CSV.generate do |column|
                column << filter['permissions'].collect do |permission|
                  permission['name']
                end
              end.delete!("\n")
              organizations = CSV.generate do |column|
                column << filter['organizations'].collect do |organization|
                  organization['name']
                end
              end.delete!("\n")
              locations = CSV.generate do |column|
                column << filter['locations'].collect do |location|
                  location['name']
                end
              end.delete!("\n")
              csv << [role['name'], 1, filter['search'], permissions, organizations, locations]
            end
          end
        end
      end

      HammerCLI::EX_OK
    end

    def import
      @existing_roles = {}
      @api.resource(:roles).call(:index, {'per_page' => 999999})['results'].each do |role|
        @existing_roles[role['name']] = role['id']
      end

      @existing_filters = {}
      @api.resource(:filters).call(:index, {'per_page' => 999999})['results'].each do |role|
        @existing_filters[role['name']] = role['id']
      end

      thread_import do |line|
        create_roles_from_csv(line)
      end
    end

    def create_roles_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        filter = namify(line[FILTER], number) if line[FILTER]

        if !@existing_roles[name]
          print "Creating role '#{name}'..." if option_verbose?
          role = @api.resource(:roles).call(:create, {
                                      'name' => name
                                    })
          @existing_roles[name] = role['id']
        else
          print "Updating role '#{name}'..." if option_verbose?
          @api.resource(:roles).call(:update, {
                               'id' => @existing_roles[name]
                             })
        end

        permissions = CSV.parse_line(line[PERMISSIONS], {:skip_blanks => true}).collect do |permission|
          foreman_permission(:name => permission)
        end if line[PERMISSIONS]
        organizations = CSV.parse_line(line[ORGANIZATIONS], {:skip_blanks => true}).collect do |organization|
          foreman_organization(:name => organization)
        end if line[ORGANIZATIONS]
        locations = CSV.parse_line(line[LOCATIONS], {:skip_blanks => true}).collect do |location|
          foreman_location(:name => location)
        end if line[LOCATIONS]

        if filter
          filter_id = foreman_filter(name, :name => filter)
          if !filter_id
            @api.resource(:filters).call(:create, {
                                   'role_id' => @existing_roles[name],
                                   'search' => filter,
                                   'organization_ids' => organizations || [],
                                   'location_ids' => locations || [],
                                   'permission_ids' => permissions || []
                                 })
          else
            @api.resource(:filters).call(:update, {
                                   'id' => filter_id,
                                   'search' => filter,
                                   'organization_ids' => organizations || [],
                                   'location_ids' => locations || [],
                                   'permission_ids' => permissions || []
                                 })
          end
        end

        puts "done" if option_verbose?
      end
    end
  end

  HammerCLICsv::CsvCommand.subcommand("roles",
                                      "import or export roles",
                                      HammerCLICsv::RolesCommand)
end
