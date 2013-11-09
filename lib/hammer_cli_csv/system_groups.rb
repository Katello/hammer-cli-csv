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
      @systemgroup_api = KatelloApi::Resources::SystemGroup.new(@init_options)
      @permission_api = KatelloApi::Resources::Permission.new(@init_options)
    end

    def execute
      # TODO: how to get verbose option value

      options['csv_export'] ? export : import  # TODO: how to access :flag option value?
    end

    def export

      # TODO: convert to use CSV gem

      file = File.new(csv_file, 'w')
      file.write "SystemGroup Name,SystemGroup Description\n"
      @systemgroup_api.index[0].each do |systemgroup|
        if !systemgroup['locked']
          file.write "#{systemgroup['name']},#{systemgroup['description']}\n"
          puts @systemgroup_api.permissions({:systemgroup_id => systemgroup['id']}, {'Accept' => 'version=2,application/json'})
        end
      end

      HammerCLI::EX_OK
    ensure
      file.close unless file.nil?
    end

    def import
      csv = get_lines(csv_file)[1..-1]
      lines_per_thread = csv.length/threads.to_i + 1
      splits = []

      threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line.index('#') != 0
              create_systemgroups_from_csv(line)
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end

      HammerCLI::EX_OK
    end

    def create_systemgroups_from_csv(line)
      details = parse_systemgroup_csv(line)

      @existing[details[:org_label]] ||= {}
      @systemgroup_api.index({'organization_id' => details[:org_label]})[0].each do |systemgroup|
          @existing[details[:org_label]][systemgroup['name']] = systemgroup['id']
      end

      #puts @systemgroup_api.index({'organization_id' => details[:org_label]})[0]
      #puts @existing['megacorp'].include? 'abc'

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing[details[:org_label]].include? name
          @systemgroup_api.create({
                             'organization_id' => details[:org_label],
                             'system_group' => {
                               'name' => name,
                               'max_systems' => (details[:limit] == 'Unlimited') ? -1 : details[:limit],
                               'description' => details[:description]
                             }
                           }, HEADERS)
        else
          puts "Update existing systemgroup '#{name}'" # TODO: verbose
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
