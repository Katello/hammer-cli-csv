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
# -= Environments CSV =-
#
# Columns
#   Name
#     - Environment name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class PuppetEnvironmentsCommand < BaseCommand
      command_name 'puppet-environments'
      desc         'import or export puppet environments'

      ORGANIZATIONS = 'Organizations'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS]
          @api.resource(:environments).call(:index, {:per_page => 999999})['results'].each do |environment|
            name = environment['name']
            count = 1
            csv << [name, count]
            raise 'TODO: organizations'
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:environments).call(:index, {:per_page => 999999})['results'].each do |environment|
          @existing[environment['name']] = environment['id'] if environment
        end

        thread_import do |line|
          create_environments_from_csv(line)
        end
      end

      def create_environments_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating environment '#{name}'..." if option_verbose?
            id = @api.resource(:environments).call(:create, {
                                             'environment' => {
                                               'name' => name
                                             }
                                           })['id']
          else
            print "Updating environment '#{name}'..." if option_verbose?
            id = @api.resource(:environments).call(:update, {
                                             'id' => @existing[name],
                                             'environment' => {
                                               'name' => name
                                             }
                                           })['environment']['id']
          end

          # Update associated resources
          # TODO: Bug #4738: organization json does not include puppet environments
          #       http://projects.theforeman.org/issues/4738#change-15319
          #       Update below to match style of domains
          organization_ids = CSV.parse_line(line[ORGANIZATIONS]).collect do |organization|
            foreman_organization(:name => organization)
          end
          organization_ids += @api.resource(:environments).call(:show, {'id' => id})['organizations'].collect do |organization|
            organization['id']
          end
          organization_ids.uniq!

          @api.resource(:environments).call(:update, {
                                              'id' => id,
                                              'environment' => {
                                                'organization_ids' => organization_ids
                                              }
                                            })

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
