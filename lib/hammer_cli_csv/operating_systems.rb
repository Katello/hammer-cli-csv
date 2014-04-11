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
# -= Operating Systems CSV =-
#
# Columns
#   Name
#     - Operating system name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Major
#   Minor
#   Family
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class OperatingSystemsCommand < BaseCommand

      command_name "operating-systems"
      desc         "import or export operating systems"

      FAMILY = 'Family'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, FAMILY]
          @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem|
            name = build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])
            count = 1
            family = operatingsystem['family']
            csv << [name, count, family]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem|
          @existing[build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])] = operatingsystem['id'] if operatingsystem
        end

        thread_import do |line|
          create_operatingsystems_from_csv(line)
        end
      end

      def create_operatingsystems_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          (osname, major, minor) = split_os_name(name)
          if !@existing.include? name
            print "Creating operating system '#{name}'..." if option_verbose?
            @api.resource(:operatingsystems).call(:create, {
                                            'operatingsystem' => {
                                              'name' => osname,
                                              'major' => major,
                                              'minor' => minor,
                                              'family' => line[FAMILY]
                                            }
                                          })
          else
            print "Updating operating system '#{name}'..." if option_verbose?
            @api.resource(:operatingsystems).call(:update, {
                                            'id' => @existing[name],
                                            'operatingsystem' => {
                                              'name' => osname,
                                              'major' => major,
                                              'minor' => minor,
                                              'family' => line[FAMILY]
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
