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
# -= Activation Key CSV =-
#
# Columns
#   Name
#     - Activation key name
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
  class ActivationKeysCommand < BaseCommand

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
        @k_organization_api.index({:per_page => 999999})[0]['results'].each do |organization|
          @k_activationkey_api.index({'per_page' => 999999,
                                       'organization_id' => organization['label']
                                     })[0]['results'].each do |activationkey|
            puts "Writing activation key '#{activationkey['name']}'" if option_verbose?
            name = namify(activationkey['name'])
            count = 1
            description = activationkey['description']
            limit = activationkey['usage_limit'].to_i < 0 ? 'Unlimited' : sytemgroup['usage_limit']
            environment = activationkey['environment']['label']
            contentview = activationkey['content_view']['name']
            systemgroups = CSV.generate do |column|
              column << activationkey['systemGroups'].collect do |systemgroup|
                systemgroup['name']
              end
            end.delete!("\n") if activationkey['systemGroups']
            subscriptions = CSV.generate do |column|
              column << @k_subscription_api.index({
                                                    'activation_key_id' => activationkey['id']
                                                  })[0]['results'].collect do |subscription|
                amount = subscription['amount'] == 0 ? 'Automatic' : subscription['amount']
                "#{amount}|#{subscription['product_name']}"
              end
            end.delete!("\n")
            csv << [name, count, organization['label'], description, limit, environment, contentview,
                    systemgroups, subscriptions]
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
        @k_activationkey_api.index({
                                     'page_size' => 999999,
                                     'organization_id' => line[ORGANIZATION]
                                   })[0]['results'].each do |activationkey|
          @existing[line[ORGANIZATION]][activationkey['name']] = activationkey['id'] if activationkey
        end
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)

        if !@existing[line[ORGANIZATION]].include? name
          print "Creating activation key '#{name}'..." if option_verbose?
          activationkey_id = @k_activationkey_api.create({
                                      'name' => name,
                                      'environment_id' => katello_environment(line[ORGANIZATION],
                                                                              :name => line[ENVIRONMENT]),
                                      'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                                               :name => line[CONTENTVIEW]),
                                      'description' => line[DESCRIPTION]
                                    })[0]['id']
        else
          print "Updating activationkey '#{name}'..." if option_verbose?
          activationkey_id = @k_activationkey_api.update({
                                        'id' => @existing[line[ORGANIZATION]][name],
                                        'name' => name,
                                        'environment_id' => katello_environment(line[ORGANIZATION],
                                                                                :name => line[ENVIRONMENT]),
                                        'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                                                 :name => line[CONTENTVIEW]),
                                        'description' => line[DESCRIPTION]
                                      })[0]['id']
        end

        if line[SUBSCRIPTIONS] && line[SUBSCRIPTIONS] != ''
          subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |subscription_details|
            subscription = {}
            (amount, name) = subscription_details.split('|')
            {
              :subscription => {
                :id => katello_subscription(line[ORGANIZATION], :name => name),
                :quantity => amount
              }
            }
          end
          @k_subscription_api.create({
                                       'activation_key_id' => activationkey_id,
                                       'subscriptions' => subscriptions
                                     })
        end

        puts "done" if option_verbose?
      end
    end

  end

  HammerCLI::MainCommand.subcommand("csv:activationkeys", "import/export activation keys", HammerCLICsv::ActivationKeysCommand)
end
