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
  class PuppetEnvironmentsCommand < BaseCommand

    def execute
      super
      csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT]
        @f_environment_api.index({:per_page => 999999}, HEADERS)[0]['results'].each do |environment|
          name = environment['name']
          count = 1
          csv << [name, count]
        end
      end
    end

    def import
      @existing = {}
      @f_environment_api.index({:per_page => 999999}, HEADERS)[0]['results'].each do |environment|
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
          print "Creating environment '#{name}'..." if verbose?
          @f_environment_api.create({
                                      'environment' => {
                                        'name' => name
                                      }
                                    }, HEADERS)
        else
          print "Updating environment '#{name}'..." if verbose?
          @f_environment_api.update({
                                      'id' => @existing[name],
                                      'environment' => {
                                        'name' => name
                                      }
                                    }, HEADERS)
        end
        print "done\n" if verbose?
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:puppetenvironments", "Import or export puppet environments", HammerCLICsv::PuppetEnvironmentsCommand)
end
