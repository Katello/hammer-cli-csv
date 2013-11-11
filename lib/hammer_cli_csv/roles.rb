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
# -= Users CSV =-
#
# Columns
#   Name
#     - Login name of the user.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "user%d" -> "user1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Description
#

require 'hammer_cli'
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class RolesCommand < BaseCommand

    def initialize(*args)
      super(args)
      @role_api = KatelloApi::Resources::Role.new(@init_options)
      @permission_api = KatelloApi::Resources::Permission.new(@init_options)
    end

    def execute
      options['csv_export'] ? export : import  # TODO: how to access :flag option value?
    end

    def export

      # TODO: convert to use CSV gem

      file = File.new(csv_file, 'w')
      file.write "Name,Count,Description\n"
      @role_api.index[0].each do |role|
        if !role['locked']
          file.write "#{role['name']},1,#{role['description']}\n"
          puts @role_api.permissions({:role_id => role['id']}, {'Accept' => 'version=2,application/json'})
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

      @existing = {}
      @role_api.index[0].each do |role|
          @existing[role['name']] = role['id']
      end

      threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line.index('#') != 0
              create_roles_from_csv(line)
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end

      HammerCLI::EX_OK
    end

    def create_roles_from_csv(line)
      details = parse_role_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing.include? name
          @role_api.create({
                             'role' => {
                               'name' => name,
                               'description' => details[:description]
                             }
                           }, {'Accept' => 'version=2,application/json'})
        else
          puts "Skip existing role '#{name}'"
        end
      end
    end

    def parse_role_csv(line)
      keys = [:name_format, :count, :description]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:roles", "ping the katello server", HammerCLICsv::RolesCommand)
end
