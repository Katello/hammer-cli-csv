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
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'

module HammerCLICsv
  class EnvironmentsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @environment_api = ForemanApi::Resources::Environment.new(@init_options[:foreman])
    end

    def execute
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file, 'wb') do |csv|
        csv << ['Name']
        @environment_api.index({}, HEADERS)[0].each do |environment|
          environment = environment['environment']
          name = environment['name']
          count = 1
          csv << [name, count]
        end
      end
    end

    def import
      @existing = {}
      @environment_api.index[0].each do |environment|
        environment = environment['environment']
        @existing[environment['name']] = environment['id']
      end

      thread_import do |line|
        create_environments_from_csv(line)
      end
    end

    def create_environments_from_csv(line)
      details = parse_environment_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing.include? name
          print "Creating environment '#{name}'..." if verbose?
          @environment_api.create({
                             'environment' => {
                               'name' => name
                             }
                           }, HEADERS)
          print "done\n" if verbose?
        else
          print "Updating environment '#{name}'..." if verbose?
          @environment_api.update({
                             'id' => @existing["#{name}-#{details[:major]}-#{details[:minor]}"],
                             'environment' => {
                               'name' => name
                             }
                           }, HEADERS)
          print "done\n" if verbose?
        end
      end
    end

    def parse_environment_csv(line)
      keys = [:name_format, :count]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:environments", "ping the katello server", HammerCLICsv::EnvironmentsCommand)
end
