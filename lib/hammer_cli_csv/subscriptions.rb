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
# -= Systems CSV =-
#
# Columns
#   Name
#     - System name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file

require 'hammer_cli'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class CsvCommand
    class SubscriptionsCommand < BaseCommand
      command_name 'subscriptions'
      desc         'import or export subscriptions'

      ORGANIZATION = 'Organization'
      MANIFEST = 'Manifest File'
      CONTENT_SET = 'Content Set'
      ARCH = 'Arch'
      RELEASE = 'Release'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, ORGANIZATION, MANIFEST, CONTENT_SET, ARCH, RELEASE]
          @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
            @api.resource(:products).call(:index, {
                'per_page' => 999999,
                'organization_id' => organization['id'],
                'enabled' => true
            })['results'].each do |product|
              if product['provider']['name'] == 'Red Hat'
                name = product['name']
                @api.resource(:repository_sets).call(:index, {
                    'per_page' => 999999,
                    'organization_id' => organization['id'],
                    'product_id' => product['id']
                })['results'].each do |repository_set|
                  content_set = repository_set['name']
                  repository_set['repositories'].each do |repository|
                    name_split = repository['name'].split(' ')
                    arch = name_split[-2]
                    release = name_split[-1]
                    csv << [name, 1, organization['name'], nil, content_set, arch, release]
                  end
                end
              end
            end
          end
        end
      end

      def import
        thread_import do |line|
          if line[MANIFEST] && !line[MANIFEST].empty?
            import_manifest_from_csv(line)
          else
            enable_products_from_csv(line)
          end
        end
      end

      def enable_products_from_csv(line)
        results = @api.resource(:products).call(:index, {
            'per_page' => 999999,
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'name' => line[NAME]
        })['results']
        raise "No match for product '#{line[NAME]}'" if results.length == 0
        raise "Multiple matches for product '#{line[NAME]}'" if results.length != 1
        product = results[0]

        results = @api.resource(:repository_sets).call(:index, {
            'per_page' => 999999,
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'product_id' => product['id'],
            'name' => line[CONTENT_SET]
        })['results']
        raise "No match for content set '#{line[CONTENT_SET]}'" if results.length == 0
        raise "Multiple matches for content set '#{line[CONTENT_SET]}'" if results.length != 1
        repository_set = results[0]

        repository = repository_set['repositories'].find do |repo|
          repo['name'].end_with?("#{line[ARCH]} #{line[RELEASE]}")
        end

        if repository.nil?
          print "Enabling repository #{line[CONTENT_SET]} #{line[ARCH]} #{line[RELEASE]}..." if option_verbose?
          product_content = product['product_content'].find do |content|
            content['content']['name'] == line[CONTENT_SET]
          end
          raise "No match for content set '#{line[CONTENT_SET]}'" if !product_content

          @api.resource(:repository_sets).call(:enable, {
              'id' => product_content['content']['id'],
              'product_id' => product['id'],
              'basearch' => line[ARCH],
              'releasever' => line[RELEASE]
          })
          puts 'done' if option_verbose?
        else
          puts "Repository #{repository['name']} already enabled" if option_verbose?
        end
      end

      def import_manifest_from_csv(line)
        args = %W{
          --server #{ @server } --username #{ @username } --password #{ @server }
          subscription upload --file #{ line[MANIFEST] }
          --organization-id #{ foreman_organization(:name => line[ORGANIZATION]) }
        }
        hammer.run(args)

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
