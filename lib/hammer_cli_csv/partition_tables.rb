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

    NAME = 'Name'
    COUNT = 'Count'
    OSFAMILY = 'OS Family'
    LAYOUT = 'Layout'

    def execute
      super
      csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, OSFAMILY, LAYOUT, OPERATINGSYSTEMS]
        @f_ptable_api.index({:per_page => 999999}, HEADERS)[0].each do |ptable|
          name = ptable['name']
          count = 1
          osfamily = ptable['os_family']
          layout = ptable['layout']
          puts ptable
          csv << [name, count, osfamily, layout]
        end
      end
    end

    def import
      @existing = {}
      @f_partitiontable_api.index({:per_page => 999999}, HEADERS)[0].each do |ptable|
        @existing[ptable['name']] = ptable['id']
      end

      thread_import do |line|
        create_ptables_from_csv(line)
      end
    end

    def create_ptables_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating ptable '#{name}'... " if verbose?
          @f_partitiontable_api.create({
                                 'ptable' => {
                                   'name' => name,
                                   'os_family' => line[OSFAMILY],
                                   'layout' => line[LAYOUT]
                             }
                           }, HEADERS)
        else
          print "Updating ptable '#{name}'..." if verbose?
          @f_partitiontable_api.update({
                                 'id' => @existing[name],
                                 'ptable' => {
                                   'name' => name,
                                   'os_family' => line[OSFAMILY],
                                   'layout' => line[LAYOUT]
                                 }
                           }, HEADERS)
        end
        print "done\n" if verbose?
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:partitiontables", "ping the katello server", HammerCLICsv::PartitionTablesCommand)
end
