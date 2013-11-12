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

    def initialize(*args)
      super(args)
      @activationkey_api = KatelloApi::Resources::ActivationKey.new(@init_options)
      @organization_api = KatelloApi::Resources::Organization.new(@init_options)
      @environment_api = KatelloApi::Resources::Environment.new(@init_options)
      @contentview_api = KatelloApi::Resources::ContentView.new(@init_options)
    end

    def execute
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file, 'wb') do |csv|
        csv << ['Name', 'Count', 'Org Label', 'Description', 'Limit', 'Environment', 'Content View', 'System Groups']
        @organization_api.index[0].each do |organization|
          @activationkey_api.index({'organization_id' => organization['label']})[0].each do |activationkey|
            puts "Writing activation key '#{activationkey['name']}'"
            csv << [activationkey['name'], 1, organization['label'],
                    activationkey['description'],
                    activationkey['usage_limit'].to_i < 0 ? 'Unlimited' : sytemgroup['usage_limit']]
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
      details = parse_activationkey_csv(line)

      if !@existing[details[:org_label]]
        @existing[details[:org_label]] = {}
        @activationkey_api.index({'organization_id' => details[:org_label]})[0].each do |activationkey|
          @existing[details[:org_label]][activationkey['name']] = activationkey['id']
        end
        @environments = {}
        @environments[details[:org_label]] = {}
        @environment_api.index({'organization_id' => details[:org_label]})[0].each do |environment|
          @environments[details[:org_label]][details[:environment]] = environment['id']
        end
        @contentviews = {}
        @contentviews[details[:org_label]] = {}
        @contentview_api.index({'organization_id' => details[:org_label]})[0].each do |contentview|
          @contentviews[details[:org_label]][details[:content_view]] = contentview['id']
        end
      end

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        if !@existing[details[:org_label]].include? name
          puts "Creating activationkey '#{name}'" if verbose?
          @activationkey_api.create({
                             'environment_id' => @environments[details[:org_label]][details[:environment]],
                             'activation_key' => {
                               'name' => name,
                               'content_view_id' => details[:content_view],
                               'description' => details[:description]
                             }
                           })
        else
          puts "Updating activationkey '#{name}'" if verbose?
          @activationkey_api.update({
                             'organization_id' => details[:org_label],
                             'id' => @existing[details[:org_label]][name],
                             'activation_key' => {
                               'name' => name,
                               'description' => details[:description]
                             }
                           })
        end
      end
    end

    def parse_activationkey_csv(line)
      keys = [:name_format, :count, :org_label, :description, :limit, :environment, :content_view, :system_groups]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:activationkeys", "ping the katello server", HammerCLICsv::ActivationKeysCommand)
end
