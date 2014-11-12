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
      HOSTCOLLECTIONS = 'System Groups'
      SUBSCRIPTIONS = 'Subscriptions'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, ORGANIZATION, DESCRIPTION, LIMIT, ENVIRONMENT, CONTENTVIEW,
                  HOSTCOLLECTIONS, SUBSCRIPTIONS]
          if @server_status['release'] == 'Headpin'
            @headpin.get(:organizations).each do |organization|
              @headpin.get("organizations/#{organization['label']}/activation_keys").each do |activationkey|
                name = namify(activationkey['name'])
                count = 1
                description = activationkey['description']
                limit = activationkey['usage_limit'].to_i < 0 ? 'Unlimited' : activationkey['usage_limit']
                environment = @headpin.environment(activationkey['environment_id'])['name']
                contentview = @headpin.content_view(activationkey['content_view_id'])['name']
                # TODO: https://bugzilla.redhat.com/show_bug.cgi?id=1160888
                #       Act keys in SAM-1 do not include system groups
                hostcollections = nil #???? export_column(activationkey, 'systemGroups', 'name')
                subscriptions = CSV.generate do |column|
                  column << activationkey['pools'].collect do |subscription|
                    amount = subscription['calculatedAttributes']['compliance_type'] == 'Stackable' ? 1 : 'Automatic'
                    "#{amount}|#{subscription['productId']}|#{subscription['productName']}"
                  end
                end
                subscriptions.delete!("\n")
                csv << [name, count, organization['label'], description, limit, environment, contentview,
                        hostcollections, subscriptions]
              end
            end
          else
            @api.resource(:organizations).call(:index, {
                :per_page => 999999
            })['results'].each do |organization|
              @api.resource(:activation_keys).call(:index, {
                  'per_page' => 999999,
                  'organization_id' => organization['id']
              })['results'].each do |activationkey|
                name = namify(activationkey['name'])
                count = 1
                description = activationkey['description']
                limit = activationkey['usage_limit'].to_i < 0 ? 'Unlimited' : activationkey['usage_limit']
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
          @api.resource(:activation_keys).call(:index, {
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
            activationkey = @api.resource(:activation_keys).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
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
            activationkey = @api.resource(:activation_keys).call(:update, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'id' => @existing[line[ORGANIZATION]][name],
                'name' => name,
                'environment_id' => lifecycle_environment(line[ORGANIZATION],
                                                          :name => line[ENVIRONMENT]),
                'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                         :name => line[CONTENTVIEW]),
                'description' => line[DESCRIPTION],
                'usage_limit' => usage_limit(line[LIMIT])
            })

            update_subscriptions(activationkey, line)
            update_groups(activationkey, line)
          end

          puts 'done' if option_verbose?
        end
      end

      def update_groups(activationkey, line)
        if line[HOSTCOLLECTIONS] && line[HOSTCOLLECTIONS] != ''
          # TODO: note that existing system groups are not removed
          CSV.parse_line(line[HOSTCOLLECTIONS], {:skip_blanks => true}).each do |name|
            @api.resource(:host_collections).call(:add_activation_keys, {
                'id' => katello_hostcollection(line[ORGANIZATION], :name => name),
                'activation_key_ids' => [activationkey['id']]
            })
          end
        end
      end

      def update_subscriptions(activationkey, line)
        if line[SUBSCRIPTIONS] && line[SUBSCRIPTIONS] != ''
          subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |subscription_details|
            (amount, sku, name) = subscription_details.split('|')
            {
              :id => katello_subscription(line[ORGANIZATION], :name => name),
              :quantity => (amount.nil? || amount == 'Automatic') ? 0 : amount
            }
          end

          existing_subscriptions = @api.resource(:subscriptions).call(:index, {
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'per_page' => 999999,
              'activation_key_id' => activationkey['id']
          })['results']
          if existing_subscriptions.length > 0
            @api.resource(:activation_keys).call(:remove_subscriptions, {
              'id' => activationkey['id'],
              'subscriptions' => existing_subscriptions
            })
          end

          @api.resource(:activation_keys).call(:add_subscriptions, {
              'id' => activationkey['id'],
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
