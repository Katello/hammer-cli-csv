# Copyright (c) 2013 Red Hat
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
  class OperatingSystemsCommand < BaseCommand

    FAMILY = 'Family'
    ARCHITECTURES = 'Architectures'
    PARTITIONTABLES = 'Partition Tables'

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, FAMILY, ARCHITECTURES, PARTITIONTABLES]
        @f_operatingsystem_api.index({:per_page => 999999}, HEADERS)[0]['results'].each do |operatingsystem|
          name = build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])
          count = 1
          family = operatingsystem['family']
          architectures = ""
          operatingsystem['architectures'].each do |architecture|
            architectures += "," unless architectures == ""
            architectures += architecture['name']
          end
          partitiontables = ""
          operatingsystem['ptables'].each do |partitiontable|
            partitiontables += "," unless partitiontables == ""
            partitiontables += partitiontable['name']
          end
          csv << [name, count, family, architectures, partitiontables]
        end
      end
    end

    def import
      @existing = {}
      @f_operatingsystem_api.index({:per_page => 999999}, HEADERS)[0]['results'].each do |operatingsystem|
        @existing[build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])] = operatingsystem['id'] if operatingsystem
      end

      thread_import do |line|
        create_operatingsystems_from_csv(line)
      end
    end

    def create_operatingsystems_from_csv(line)
      architecture_ids = CSV.parse_line(line[ARCHITECTURES]).collect do |name|
        foreman_architecture(:name => name)
      end unless line[ARCHITECTURES].empty?
      architecture_ids ||= []
      partitiontable_ids = CSV.parse_line(line[PARTITIONTABLES]).collect do |name|
        foreman_partitiontable(:name => name)
      end unless line[PARTITIONTABLES].empty?
      partitiontables_ids ||= []

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        (osname, major, minor) = split_os_name(name)
        if !@existing.include? name
          print "Creating operating system '#{name}'..." if verbose?
          @f_operatingsystem_api.create({
                                          'operatingsystem' => {
                                            'name' => osname,
                                            'major' => major,
                                            'minor' => minor,
                                            'family' => line[FAMILY],
                                            'architecture_ids' => architecture_ids,
                                            'ptable_ids' => partitiontable_ids
                                          }
                                        }, HEADERS)
        else
          print "Updating operatingsystem '#{name}'..." if verbose?
          @f_operatingsystem_api.update({
                                          'id' => @existing[name],
                                          'operatingsystem' => {
                                            'name' => osname,
                                            'major' => major,
                                            'minor' => minor,
                                            'family' => line[FAMILY],
                                            'architecture_ids' => architecture_ids,
                                            'ptable_ids' => partitiontable_ids
                                          }
                                        }, HEADERS)
        end
        print "done\n" if verbose?
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:operatingsystems", "ping the katello server", HammerCLICsv::OperatingSystemsCommand)
end
