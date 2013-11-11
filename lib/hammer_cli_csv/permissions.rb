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
#   Login
#     - Login name of the user.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "user%d" -> "user1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   First Name
#   Last Name
#   Email
#

require 'hammer_cli'
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class PermissionsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @role_api = KatelloApi::Resources::Role.new(@init_options)
      @permission_api = KatelloApi::Resources::Permission.new(@init_options)
    end

    def execute
      # TODO: how to get verbose option value

      options['csv_export'] ? export : import  # TODO: how to access :flag option value?
    end

    def export
      # TODO
    end

    def import
      csv = get_lines(csv_file)[1..-1]
      lines_per_thread = csv.length/threads.to_i + 1
      splits = []

      @roles = {}
      @role_api.index[0].each do |role|
          @roles[role['name']] = role['id']
      end

      @existing = {}

      threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line.index('#') != 0
              create_permissions_from_csv(line)
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end

      HammerCLI::EX_OK
    end

    def create_permissions_from_csv(line)
      details = parse_permission_csv(line)

      puts @permission_api.index({'role_id' => @roles['User System Group']})[0]
      # {"all_tags"=>false, "all_verbs"=>false, "created_at"=>"2013-11-11T02:31:23Z", "description"=>"and it's description!", "id"=>12, "name"=>"Accounting System Group Modify Systems", "organization_id"=>2, "resource_type_id"=>5, "role_id"=>124, "updated_at"=>"2013-11-11T02:31:23Z", "tags"=>[{"created_at"=>"2013-11-11T02:31:23Z", "formatted"=>{"name"=>6, "display_name"=>"Accounting"}, "id"=>2, "permission_id"=>12, "tag_id"=>6, "updated_at"=>"2013-11-11T02:31:23Z"}], "verbs"=>[{"created_at"=>"2013-11-07T19:44:45Z", "id"=>7, "updated_at"=>"2013-11-07T19:44:45Z", "verb"=>"update_systems"}], "resource_type"=>{"created_at"=>"2013-11-07T16:36:56Z", "id"=>5, "name"=>"system_groups", "updated_at"=>"2013-11-07T16:36:56Z"}}

      @existing[@roles[details[:role]]] ||= {}
      @permission_api.index({'role_id' => @roles[details[:role]]})[0].each do |permission|
          @existing[@roles[details[:role]]][permission['name']] = permission['id']
      end

      puts @existing
      return 1

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing.include? name
          @permission_api.create({
                             :permission => {
                               :name => name,
                               :email => details[:email],
                               :password => 'admin'
                             }
                           }, {'Accept' => 'version=2,application/json'})
        else
          puts "Skip existing permission '#{name}'"
        end
      end
    end

    def parse_permission_csv(line)
      keys = [:name_format, :count, :role, :description]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:permissions", "ping the katello server", HammerCLICsv::PermissionsCommand)
end
