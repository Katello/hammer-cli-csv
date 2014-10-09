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
    class RolesCommand < BaseCommand
      command_name 'roles'
      desc 'import or export roles'

      RESOURCE = 'Resource'
      SEARCH = 'Search'
      PERMISSIONS = 'Permissions'
      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, RESOURCE, SEARCH, PERMISSIONS, ORGANIZATIONS, LOCATIONS]
          @api.resource(:roles).call(:index, {'per_page' => 999999})['results'].each do |role|
            @api.resource(:filters).call(:index, {
                                           'per_page' => 999999,
                                           'search' => "role=\"#{role['name']}\""
                                })['results'].each do |filter|
              filter = @api.resource(:filters).call(:show, 'id' => filter['id'])

              permissions = export_column(filter, 'permissions', 'name')
              organizations = export_column(filter, 'organizations', 'name')
              locations = export_column(filter, 'locations', 'name')
              csv << [role['name'], 1, filter['resource_type'], filter['search'] || '', permissions, organizations, locations]
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

        permissions = collect_column(line[PERMISSIONS]) do |permission|
          foreman_permission(:name => permission)
        end
        organizations = collect_column(line[ORGANIZATIONS]) do |organization|
          foreman_organization(:name => organization)
        end
        locations = collect_column(line[LOCATIONS]) do |location|
          foreman_location(:name => location)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          search = line[SEARCH] ? namify(line[SEARCH], number) : nil

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

          filter_id = foreman_filter(name, line[RESOURCE], search)
          if !filter_id
            print " creating filter #{line[RESOURCE]}..." if option_verbose?
            @api.resource(:filters).call(:create, { 'filter' => {
                                           'role_id' => @existing_roles[name],
                                           'search' => search,
                                           'organization_ids' => organizations,
                                           'location_ids' => locations,
                                           'permission_ids' => permissions
                                         }})
          else
            print " updating filter #{line[RESOURCE]}..."
            @api.resource(:filters).call(:update, {
                                           'id' => filter_id,
                                           'search' => search,
                                           'organization_ids' => organizations,
                                           'location_ids' => locations,
                                           'permission_ids' => permissions
                                         })
          end

          puts 'done' if option_verbose?
        end
      end
    end
  end
end
