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
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'

module HammerCLICsv
  class OperatingSystemsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @operatingsystem_api = ForemanApi::Resources::OperatingSystem.new(@init_options[:foreman])
    end

    def execute
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file, 'wb') do |csv|
        csv << ['Name','Count','Major','Minor', 'Family']
        @operatingsystem_api.index({}, HEADERS)[0].each do |operatingsystem|
          name = operatingsystem['operatingsystem']['name']
          count = 1
          major = operatingsystem['operatingsystem']['major']
          minor = operatingsystem['operatingsystem']['minor']
          family = operatingsystem['operatingsystem']['family']
          csv << [name, count, major, minor, family]
        end
      end
    end

    def import
      @existing = {}
      @operatingsystem_api.index[0].each do |operatingsystem|
        operatingsystem = operatingsystem['operatingsystem']
        @existing["#{operatingsystem['name']}-#{operatingsystem['major']}-#{operatingsystem['minor']}"] = operatingsystem['id']
      end

      thread_import do |line|
        create_operatingsystems_from_csv(line)
      end
    end

    def create_operatingsystems_from_csv(line)
      details = parse_operatingsystem_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing.include? "#{name}-#{details[:major]}-#{details[:minor]}"
          print "Creating operating system '#{name}'..." if verbose?
          @operatingsystem_api.create({
                             'operatingsystem' => {
                               'name' => name,
                               'major' => details[:major],
                               'minor' => details[:minor],
                               'family' => details[:family]
                             }
                           }, HEADERS)
          print "done\n" if verbose?
        else
          print "Updating operatingsystem '#{name}'..." if verbose?
          @operatingsystem_api.create({
                             'id' => @existing["#{name}-#{details[:major]}-#{details[:minor]}"],
                             'operatingsystem' => {
                               'name' => name,
                               'major' => details[:major],
                               'minor' => details[:minor],
                               'family' => details[:family]
                             }
                           }, HEADERS)
          print "done\n" if verbose?
        end
      end
    end

    def parse_operatingsystem_csv(line)
      keys = [:name_format, :count, :major, :minor, :family]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:operatingsystems", "ping the katello server", HammerCLICsv::OperatingSystemsCommand)
end
