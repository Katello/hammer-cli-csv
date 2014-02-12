# Copyright (c) 2013-2014 Red Hat
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
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
require 'katello_api'
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
        @f_role_api.index({'per_page' => 999999})[0]['results'].each do |role|
          @f_filter_api.index({
                                'per_page' => 999999,
                                'search' => "role=\"#{role['name']}\""
                              })[0]['results'].each do |filter|
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
      @f_role_api.index({'per_page' => 999999})[0]['results'].each do |role|
        @existing_roles[role['name']] = role['id']
      end

      @existing_filters = {}
      @f_filter_api.index({'per_page' => 999999})[0]['results'].each do |role|
        @existing_filters[role['name']] = role['id']
      end

      thread_import do |line|
        create_roles_from_csv(line)
      end
    end

    def create_roles_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        filter = namify(line[FILTER], number)

        if !@existing_roles[name]
          print "Creating role '#{name}'..." if option_verbose?
        else
          print "Updating role '#{name}'..." if option_verbose?
          @f_role_api.update({
                               'id' => @existing_roles[name]
                             })
        end

        permissions = CSV.parse_line(line[PERMISSIONS], {:skip_blanks => true}).collect do |permission|
          foreman_permission(:name => permission)
        end
        puts permissions
        organizations = CSV.parse_line(line[ORGANIZATIONS], {:skip_blanks => true}).collect do |organization|
          foreman_organization(:name => organization)
        end
        locations = CSV.parse_line(line[LOCATIONS], {:skip_blanks => true}).collect do |location|
          foreman_location(:name => location)
        end

        filter_id = foreman_filter(name, :name => filter)
        if !filter_id
          @f_filter_api.create({
                                 'role_id' => @existing_roles[name],
                                 'search' => filter,
                                 'organization_ids' => organizations,
                                 'location_ids' => locations
                               })
        else
          @f_filter_api.update({
                                 'id' => filter_id,
                                 'search' => filter,
                                 'organization_ids' => organizations,
                                 'location_ids' => locations,
                                 'permission_ids' => permissions
                               })
        end

        puts "done" if option_verbose?
      end
    end
  end

  HammerCLI::MainCommand.subcommand("csv:roles", "import / export roles", HammerCLICsv::RolesCommand)
end
