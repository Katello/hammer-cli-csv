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
# -= Architectures CSV =-
#
# Columns
#   Name
#     - Architecture name
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
    class ArchitecturesCommand < BaseCommand
      command_name 'architectures'
      desc         'import or export architectures'

      OPERATINGSYSTEMS = 'Operating Systems'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, OPERATINGSYSTEMS]
          @api.resource(:architectures).call(:index, {:per_page => 999999})['results'].each do |architecture|
            name = architecture['name']
            count = 1
            # TODO: http://projects.theforeman.org/issues/4198
            #operatingsystems = architecture['operatingsystem_ids'].collect do |operatingsystem_id|
            #  foreman_operatingsystem(:id => operatingsystem_id)
            #end.join(',')
            operatingsystems = ''
            csv << [name, count, operatingsystems]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:architectures).call(:index, {:per_page => 999999})['results'].each do |architecture|
          @existing[architecture['name']] = architecture['id'] if architecture
        end

        thread_import do |line|
          create_architectures_from_csv(line)
        end
      end

      def create_architectures_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          architecture_id = @existing[name]
          operatingsystem_ids = CSV.parse_line(line[OPERATINGSYSTEMS]).collect do |operatingsystem_name|
            foreman_operatingsystem(:name => operatingsystem_name)
          end
          if !architecture_id
            print "Creating architecture '#{name}'..." if option_verbose?
            architecture_id = @api.resource(:architectures).call(:create, {
                               'architecture' => {
                                 'name' => name,
                                 'operatingsystem_ids' => operatingsystem_ids
                               }
                             })
          else
            print "Updating architecture '#{name}'..." if option_verbose?
            @api.resource(:architectures).call(:update, {
                               'id' => architecture_id,
                               'architecture' => {
                                 'name' => name,
                                 'operatingsystem_ids' => operatingsystem_ids
                               }
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
