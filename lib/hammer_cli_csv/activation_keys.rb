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

module HammerCLICsv
  class CsvCommand
    class ActivationKeysCommand < BaseCommand
      command_name 'activation-keys'
      desc         'import or export activation keys'

      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      LIMIT = 'Limit'
      ENVIRONMENT = 'Environment'
      CONTENTVIEW = 'Content View'
      SYSTEMGROUPS = 'System Groups'
      SUBSCRIPTIONS = 'Subscriptions'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, ORGANIZATION, DESCRIPTION, LIMIT, ENVIRONMENT, CONTENTVIEW,
                  SYSTEMGROUPS, SUBSCRIPTIONS]
          @api.resource(:organizations)\
            .call(:index, {
                    :per_page => 999999
                  })['results'].each do |organization|
            @api.resource(:activation_keys)\
              .call(:index, {
                      'per_page' => 999999,
                      'organization_id' => organization['id']
                    })['results'].each do |activationkey|
              puts "Writing activation key '#{activationkey['name']}'" if option_verbose?
              name = namify(activationkey['name'])
              count = 1
              description = activationkey['description']
              limit = activationkey['usage_limit'].to_i < 0 ? 'Unlimited' : sytemgroup['usage_limit']
              environment = activationkey['environment']['label']
              contentview = activationkey['content_view']['name']
              hostcollections = export_column(activationkey, 'systemGroups', 'name')
              subscriptions = CSV.generate do |column|
                column << @api.resource(:subscriptions).call(:index, {
                                                      'activation_key_id' => activationkey['id']
                                                    })['results'].collect do |subscription|
                  amount = subscription['amount'] == 0 ? 'Automatic' : subscription['amount']
                  "#{amount}|#{subscription['product_name']}"
                end
              end
              subscriptions.delete!("\n")
              csv << [name, count, organization['label'], description, limit, environment, contentview,
                      hostcollections, subscriptions]
            end
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_activationkeys_from_csv(line)
        end
      end

      def create_activationkeys_from_csv(line)
        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          @api.resource(:activation_keys)\
            .call(:index, {
                    'per_page' => 999999,
                    'organization_id' => foreman_organization(:name => line[ORGANIZATION])
                  })['results'].each do |activationkey|
            @existing[line[ORGANIZATION]][activationkey['name']] = activationkey['id'] if activationkey
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          if !@existing[line[ORGANIZATION]].include? name
            print "Creating activation key '#{name}'..." if option_verbose?
            activationkey = @api.resource(:activation_keys)\
              .call(:create, {
                      'name' => name,
                      'environment_id' => lifecycle_environment(line[ORGANIZATION],
                                                                :name => line[ENVIRONMENT]),
                      'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                               :name => line[CONTENTVIEW]),
                      'description' => line[DESCRIPTION],
                      'usage_limit' => usage_limit(line[LIMIT])
                    })
            @existing[line[ORGANIZATION]][activationkey['name']] = activationkey['id']
          else
            print "Updating activation key '#{name}'..." if option_verbose?
            activationkey = @api.resource(:activation_keys)\
              .call(:update, {
                      'id' => @existing[line[ORGANIZATION]][name],
                      'name' => name,
                      'environment_id' => lifecycle_environment(line[ORGANIZATION],
                                                                :name => line[ENVIRONMENT]),
                      'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                               :name => line[CONTENTVIEW]),
                      'description' => line[DESCRIPTION],
                      'usage_limit' => usage_limit(line[LIMIT])
                    })
          end

          update_subscriptions(activationkey, line)
          update_groups(activationkey, line)

          puts 'done' if option_verbose?
        end
      end

      def update_groups(activationkey, line)
        if line[SYSTEMGROUPS] && line[SYSTEMGROUPS] != ''
          # TODO: note that existing system groups are not removed
          CSV.parse_line(line[SYSTEMGROUPS], {:skip_blanks => true}).each do |name|
            @api.resource(:host_collections)\
              .call(:add_activation_keys, {
                      'id' => katello_hostcollection(line[ORGANIZATION], :name => name),
                      'activation_key_ids' => [activationkey['id']]
                    })
          end
        end
      end

      def update_subscriptions(activationkey, line)
        if line[SUBSCRIPTIONS] && line[SUBSCRIPTIONS] != ''
          subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |subscription_details|
            (amount, name) = subscription_details.split('|')
            {
              :id => katello_subscription(line[ORGANIZATION], :name => name),
              :quantity => amount
            }
          end

          # TODO: should there be a destroy_all similar to systems?
          @api.resource(:subscriptions)\
            .call(:index, {
                    'per_page' => 999999,
                    'activation_key_id' => activationkey['id']
                  })['results'].each do |subscription|
            @api.resource(:subscriptions)\
              .call(:destroy, {
                      'id' => subscription['id'],
                      'activation_key_id' => activationkey['id']
                    })
          end

          @api.resource(:subscriptions)\
            .call(:create, {
                    'activation_key_id' => activationkey['id'],
                    'subscriptions' => subscriptions
                  })
        end
      end

      def usage_limit(limit)
        Integer(limit) rescue -1
      end
    end
  end
end
