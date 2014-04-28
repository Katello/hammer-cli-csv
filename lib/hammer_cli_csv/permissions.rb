# Copyright 2013-2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

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
#   Role
#   Description
#   Category
#     - organizations, environments, activation_keys, system_groups, providers, users, roles,
#       content_view_definitions, content_views, all
#   Verbs
#     organizations - gpg, redhat_products, delete_distributors, delete_systems, manage_nodes,
#                     update_distributors, update, update_systems, read_distributors, read,
#                     read_systems, register_distributors, register_systems, sync
#     environments - manage_changesets, delete_changesets, update_distributors, update_systems,
#                    promote_changesets, read_changesets, read_distributors, read_contents, read_systems,
#                    register_distributors, register_systems, delete_distributors, delete_systems
#     activation_keys - manage_all, read_all
#     system_groups - create, delete, delete_systems, update, update_systems, read, read_systems
#     providers - create, delete, update, read
#     users - create, delete, update, read
#     roles - create, delete, update, read
#     content_view_definitions - create, delete, update, publish, read
#     content_views - promote, read, subscribe
#     all
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class PermissionsCommand < BaseCommand

      command_name "permissions"
      desc         "import or export permissions"

      def initialize(*args)
        super(args)
        @role_api = KatelloApi::Resources::Role.new(@init_options)
        @permission_api = KatelloApi::Resources::Permission.new(@init_options)
      end

      def export
        # TODO
      end

      def import
        csv = get_lines(option_csv_file)[1..-1]
        lines_per_thread = csv.length/threads.to_i + 1
        splits = []

        @roles = {}
        @role_api.index[0].each do |role|
            @roles[role['name']] = role['id']
        end

        @verbs = {}
        puts @role_api.available_verbs[0]
        return HammerCLI::EX_OK
        @role_api.available_verbs[0].each do |verb|
            @verbs[verb['name']] = verb['id']
        end

        puts @verbs
        return

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

        puts @permission_api.index({'role_id' => @roles['User System Group']})
        # {"all_tags"=>false, "all_verbs"=>false, "created_at"=>"2013-11-11T02:31:23Z", "description"=>"and it's description!", "id"=>12, "name"=>"Accounting System Group Modify Systems", "organization_id"=>2, "resource_type_id"=>5, "role_id"=>124, "updated_at"=>"2013-11-11T02:31:23Z", "tags"=>[{"created_at"=>"2013-11-11T02:31:23Z", "formatted"=>{"name"=>6, "display_name"=>"Accounting"}, "id"=>2, "permission_id"=>12, "tag_id"=>6, "updated_at"=>"2013-11-11T02:31:23Z"}], "verbs"=>[{"created_at"=>"2013-11-07T19:44:45Z", "id"=>7, "updated_at"=>"2013-11-07T19:44:45Z", "verb"=>"update_systems"}], "resource_type"=>{"created_at"=>"2013-11-07T16:36:56Z", "id"=>5, "name"=>"system_groups", "updated_at"=>"2013-11-07T16:36:56Z"}}

        @existing[@roles[details[:role]]] ||= {}
        @permission_api.index({'role_id' => @roles[details[:role]]}).each do |permission|
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
  end
end
