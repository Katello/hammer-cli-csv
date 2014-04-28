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
    class LifecycleEnvironmentsCommand < BaseCommand

      command_name "lifecycle-environment"
      desc         "import or export lifecycle environments"

      LABEL = "Label"
      ORGANIZATION = "Organization"
      PRIORENVIRONMENT = "Prior Environment"
      DESCRIPTION = "Description"

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, LABEL, ORGANIZATION, PRIORENVIRONMENT, DESCRIPTION]
          @api.resource(:organizations).call(:index, {'per_page' => 999999})['results'].each do |organization|
            @api.resource(:environments).call(:index, {
                                       'per_page' => 999999,
                                       'organization_id' => organization['label']
                                     })['results'].each do |environment|
              if environment['label'] != 'Library'
                name = environment['name']
                count = 1
                label = environment['label']
                prior = environment['prior']
                description = environment['description']
                csv << [name, count, label, organization['name'], prior, description]
              end
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:organizations).call(:index, {'per_page' => 999999})['results'].each do |organization|
          @api.resource(:environments).call(:index, {
                                     'per_page' => 999999,
                                     'organization_id' => katello_organization(:name => organization['name']),
                                     'library' => true
                                   })['results'].each do |environment|
            @existing[organization['name']] ||= {}
            @existing[organization['name']][environment['name']] = environment['id'] if environment
          end
        end

        thread_import do |line|
          create_environments_from_csv(line)
        end
      end

      def create_environments_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          label = namify(line[LABEL], number)
          prior = namify(line[PRIORENVIRONMENT], number)
          raise "Organization '#{line[ORGANIZATION]}' does not exist" if !@existing.include? line[ORGANIZATION]
          if !@existing[line[ORGANIZATION]].include? name
            print "Creating environment '#{name}'..." if option_verbose?
            @api.resource(:environments).call(:create, {
                                        'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                        'name' => name,
                                        'label' => label,
                                        'prior' => katello_environment(line[ORGANIZATION], :name => prior),
                                        'description' => line[DESCRIPTION]
                                      })
          else
            print "Updating environment '#{name}'..." if option_verbose?
            @api.resource(:environments).call(:update, {
                                        'id' => @existing[line[ORGANIZATION]][name],
                                        'name' => name,
                                        'new_name' => name,
                                        'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                        'prior' => prior,
                                        'description' => line[DESCRIPTION]
                                      })
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
