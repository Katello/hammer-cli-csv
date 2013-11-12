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
# -= System Groups CSV =-
#
# Columns
#   Name
#     - System group name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "group%d" -> "group1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Org Label
#   Limit
#   Description
#

require 'hammer_cli'
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class SystemGroupsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @organization_api = KatelloApi::Resources::Organization.new(@init_options)
      @systemgroup_api = KatelloApi::Resources::SystemGroup.new(@init_options)
      @permission_api = KatelloApi::Resources::Permission.new(@init_options)
    end

    def execute
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file, 'wb') do |csv|
        csv << ['Name', 'Count', 'Org Label', 'Limit', 'Description']
        @organization_api.index[0].each do |organization|
          @systemgroup_api.index({'organization_id' => organization['label']})[0].each do |systemgroup|
            puts systemgroup
            csv << [systemgroup['name'], 1, organization['label'],
                    systemgroup['max_systems'].to_i < 0 ? 'Unlimited' : sytemgroup['max_systems'],
                    systemgroup['description']]
          end
        end
      end
    end

    def import
      @existing = {}

      thread_import do |line|
        create_systemgroups_from_csv(line)
      end
    end

    def create_systemgroups_from_csv(line)
      details = parse_systemgroup_csv(line)

      @existing[details[:org_label]] ||= {}
      @systemgroup_api.index({'organization_id' => details[:org_label]})[0].each do |systemgroup|
          @existing[details[:org_label]][systemgroup['name']] = systemgroup['id']
      end

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing[details[:org_label]].include? name
          puts "Creating system group '#{name}'" if verbose?
          @systemgroup_api.create({
                             'organization_id' => details[:org_label],
                             'system_group' => {
                               'name' => name,
                               'max_systems' => (details[:limit] == 'Unlimited') ? -1 : details[:limit],
                               'description' => details[:description]
                             }
                           }, HEADERS)
        else
          puts "Updating systemgroup '#{name}'" if verbose?
          @systemgroup_api.update({
                             'organization_id' => details[:org_label],
                             'id' => @existing[details[:org_label]][name],
                             'system_group' => {
                               'name' => name,
                               'max_systems' => (details[:limit] == 'Unlimited') ? -1 : details[:limit],
                               'description' => details[:description]
                             }
                           }, HEADERS)
        end
      end
    end

    def parse_systemgroup_csv(line)
      keys = [:name_format, :count, :org_label, :limit, :description]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:systemgroups", "ping the katello server", HammerCLICsv::SystemGroupsCommand)
end
