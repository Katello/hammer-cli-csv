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

    NAME = 'Name'
    COUNT = 'Count'
    OPERATINGSYSTEMS = 'Operating Systems'

    def execute
      super
      csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, OPERATINGSYSTEMS]
        @f_architecture_api.index({:per_page => 999999}, HEADERS)[0].each do |architecture|
          name = architecture['name']
          count = 1
          operatingsystems = architecture['operatingsystem_ids'].collect do |operatingsystem_id|
            foreman_operatingsystem(:id => operatingsystem_id)
          end.join(',')
          csv << [name, count, operatingsystems]
        end
      end
    end

    def import
      @existing = {}
      @f_architecture_api.index({:per_page => 999999}, HEADERS)[0].each do |architecture|
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
        if !architecture_id
          print "Creating architecture '#{name}'..." if verbose?
          architecture_id = @f_architecture_api.create({
                             'architecture' => {
                               'name' => name
                             }
                           }, HEADERS)
        else
          print "Updating architecture '#{name}'..." if verbose?
          @f_architecture_api.update({
                             'id' => architecture_id,
                             'architecture' => {
                               'name' => name
                             }
                           }, HEADERS)
        end

=begin
        # Update operating systems refered to
        CSV.parse_line(line[OPERATINGSYSTEMS]).each do |operatingsystem_name|
          operatingsystem = @f_operatingsystem_api.show({
                                                          'id' => foreman_operatingsystem(:name => operatingsystem_name)
                                                        }, HEADERS)[0]
          architecture_ids = operatingsystem['architectures'].collect { |a| a['id'] }
          if !architecture_ids.include? architecture_id
            architecture_ids << architecture_id
            @f_operatingsystem_api.update({
                                            'id' => operatingsystem['id'],
                                            'operatingsystem' => {
                                              'architecture_ids' => architecture_ids
                                            }
                                          }, HEADERS)
          end
        end
=end

        print "done\n" if verbose?
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:architectures", "ping the katello server", HammerCLICsv::ArchitecturesCommand)
end
