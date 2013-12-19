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

    ORGANIZATION = 'Organization'
    LIMIT = 'Limit'
    DESCRIPTION = 'Description'

    def export
      CSV.open(option_csv_file, 'wb') do |csv|
        csv << [NAME, COUNT, ORGANIZATION, LIMIT, DESCRIPTION]
        @f_organization_api.index[0].each do |organization|
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
      if !@existing[line[ORGANIZATION]]
        @existing[line[ORGANIZATION]] = {}
        @k_systemgroup_api.index({'organization_id' => line[ORGANIZATION]})[0]['results'].each do |systemgroup|
          @existing[line[ORGANIZATION]][systemgroup['name']] = systemgroup['id']
        end
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing[line[ORGANIZATION]].include? name
          print "Creating system group '#{name}'..." if option_verbose?
          @k_systemgroup_api.create({
                                    'organization_id' => line[ORGANIZATION],
                                    'name' => name,
                                    'max_systems' => (line[LIMIT] == 'Unlimited') ? -1 : line[LIMIT],
                                    'description' => line[DESCRIPTION]
                                  })
        else
          print "Updating systemgroup '#{name}'..." if option_verbose?
          @k_systemgroup_api.update({
                                      'organization_id' => line[ORGANIZATION],
                                      'id' => @existing[line[ORGANIZATION]][name],
                                      'name' => name,
                                      'max_systems' => (line[LIMIT] == 'Unlimited') ? -1 : line[LIMIT],
                                      'description' => line[DESCRIPTION]
                                    })
        end
    print "done\n" if option_verbose?
      end
    end
  end

  HammerCLI::MainCommand.subcommand("csv:systemgroups", "system groups", HammerCLICsv::SystemGroupsCommand)
end
