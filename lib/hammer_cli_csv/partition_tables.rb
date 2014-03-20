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
# -= Partition Tables CSV =-
#
# Columns
#   Name
#     - Partition table name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class PartitionTablesCommand < BaseCommand

    OSFAMILY = 'OS Family'
    OPERATINGSYSTEMS = 'Operating Systems'
    LAYOUT = 'Layout'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, OSFAMILY, OPERATINGSYSTEMS, LAYOUT]
        @api.resource(:ptables).call(:index, {:per_page => 999999})['results'].each do |ptable|
          ptable = @api.resource(:ptables).call(:show, {'id' => ptable['id']})
          name = ptable['name']
          count = 1
          osfamily = ptable['os_family']
          layout = ptable['layout']
          raise "TODO: operating systems"
          csv << [name, count, osfamily, layout]
        end
      end
    end

    def import
      @existing = {}
      @api.resource(:ptables).call(:index, {:per_page => 999999})['results'].each do |ptable|
        @existing[ptable['name']] = ptable['id'] if ptable
      end

      thread_import do |line|
        create_ptables_from_csv(line)
      end
    end

    def create_ptables_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        operatingsystem_ids = CSV.parse_line(line[OPERATINGSYSTEMS]).collect do |operatingsystem_name|
          foreman_operatingsystem(:name => operatingsystem_name)
        end if line[OPERATINGSYSTEMS]
        if !@existing.include? name
          print "Creating ptable '#{name}'... " if option_verbose?
          @api.resource(:ptables).call(:create, {
                                         'ptable' => {
                                           'name' => name,
                                           'os_family' => line[OSFAMILY],
                                           'operatingsystem_ids' => operatingsystem_ids,
                                           'layout' => line[LAYOUT]
                                         }
                                       })
        else
          print "Updating ptable '#{name}'..." if option_verbose?
          @api.resource(:ptables).call(:update, {
                                         'id' => @existing[name],
                                         'ptable' => {
                                           'name' => name,
                                           'os_family' => line[OSFAMILY],
                                           'operatingsystem_ids' => operatingsystem_ids,
                                           'layout' => line[LAYOUT]
                                 }
                           })
        end
        print "done\n" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:partitiontables", "ping the katello server", HammerCLICsv::PartitionTablesCommand)
end
