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
    class UsersCommand < BaseCommand
      command_name 'users'
      desc         'import or export users'

      FIRSTNAME = 'First Name'
      LASTNAME = 'Last Name'
      EMAIL = 'Email'
      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      ROLES = 'Roles'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, FIRSTNAME, LASTNAME, EMAIL, ORGANIZATIONS, LOCATIONS, ROLES]
          @api.resource(:users).call(:index, {:per_page => 999999})['results'].each do |user|
            if user['organizations']
              organizations = CSV.generate do |column|
                column << user['organizations'].collect do |organization|
                  organization['name']
                end
              end
              organizations.delete!("\n")
            end
            if user['locations']
              locations = CSV.generate do |column|
                column << user['locations'].collect do |location|
                  location['name']
                end
              end
              locations.delete!("\n")
            end
            if user['roles']
              roles = CSV.generate do |column|
                column << user['roles'].collect do |role|
                  role['name']
                end
              end
              roles.delete!("\n")
            end
            if user['login'] != 'admin' && !user['login'].start_with?('hidden-')
              csv << [user['login'], 1, user['firstname'], user['lastname'], user['mail'],
                      organizations, locations, roles]
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:users).call(:index, {:per_page => 999999})['results'].each do |user|
          @existing[user['login']] = user['id'] if user
        end

        thread_import do |line|
          create_users_from_csv(line)
        end
      end

      def create_users_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          roles = collect_column(line[ROLES]) do |role|
            foreman_role(:name => role)
          end
          organizations = collect_column(line[ORGANIZATIONS]) do |organization|
            foreman_organization(:name => organization)
          end
          locations = collect_column(line[LOCATIONS]) do |location|
            foreman_location(:name => location)
          end

          if !@existing.include? name
            create_user(line, name, roles, organizations, locations)
          else
            update_user(line, name, roles, organizations, locations)
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      def create_user(line, name, roles, organizations, locations)
        print "Creating user '#{name}'... " if option_verbose?
        @api.resource(:users).call(:create, {
                                     'login' => name,
                                     'firstname' => line[FIRSTNAME],
                                     'lastname' => line[LASTNAME],
                                     'mail' => line[EMAIL],
                                     'password' => 'changeme',
                                     'auth_source_id' => 1,  # INTERNAL auth
                                     'organization_ids' => organizations,
                                     'location_ids' => locations,
                                     'role_ids' => roles
                                   })
      end

      def update_user(line, name, roles, organizations, locations)
        print "Updating user '#{name}'... " if option_verbose?
        @api.resource(:users).call(:update, {
                                     'id' => @existing[name],
                                     'login' => name,
                                     'firstname' => line[FIRSTNAME],
                                     'lastname' => line[LASTNAME],
                                     'mail' => line[EMAIL],
                                     'password' => 'changeme',
                                     'organization_ids' => organizations,
                                     'location_ids' => locations,
                                     'role_ids' => roles
                                   })
      end
    end
    autoload_subcommands
  end
end
