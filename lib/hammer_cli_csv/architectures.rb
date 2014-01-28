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
require 'foreman_api'
require 'json'
require 'csv'

module HammerCLICsv
  class ArchitecturesCommand < BaseCommand

    OPERATINGSYSTEMS = 'Operating Systems'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, ORGANIZATIONS, OPERATINGSYSTEMS]
        @f_architecture_api.index({:per_page => 999999})[0]['results'].each do |architecture|
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
      @f_architecture_api.index({:per_page => 999999})[0]['results'].each do |architecture|
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
          architecture_id = @f_architecture_api.create({
                             'architecture' => {
                               'name' => name,
                               'operatingsystem_ids' => operatingsystem_ids
                             }
                           })
        else
          print "Updating architecture '#{name}'..." if option_verbose?
          @f_architecture_api.update({
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

  HammerCLI::MainCommand.subcommand("csv:architectures", "ping the katello server", HammerCLICsv::ArchitecturesCommand)
end
