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
    class ProductsCommand < BaseCommand
      command_name 'products'
      desc         'import or export products'

      LABEL = 'Label'
      ORGANIZATION = 'Organization'
      REPOSITORY = 'Repository'
      REPOSITORY_TYPE = 'Repository Type'
      REPOSITORY_URL = 'Repository Url'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, LABEL, ORGANIZATION, REPOSITORY, REPOSITORY_TYPE, REPOSITORY_URL]
          @api.resource(:organizations)
            .call(:index, {
                    :per_page => 999999
                  })['results'].each do |organization|
            @api.resource(:products)
              .call(:index, {
                      'per_page' => 999999,
                      'enabled' => true,
                      'organization_id' => foreman_organization(:name => organization['name'])
                    })['results'].each do |product|
              product['repositories'].each do |repository|
                repository_type = repository['product_type'] == 'custom' ? 'Custom' : 'Red Hat'
                repository_type += " #{repository['content_type'].capitalize}"
                csv << [product['name'], 1, product['label'], organization['name'],
                        repository['name'], repository_type, repository['url']]
              end
            end
          end
        end
      end

      def import
        @existing_products = {}
        @existing_repositories = {}

        thread_import do |line|
          create_products_from_csv(line)
        end
      end

      def create_products_from_csv(line)
        if !@existing_products[line[ORGANIZATION]]
          @existing_products[line[ORGANIZATION]] = {}
          @api.resource(:products)
            .call(:index, {
                    'per_page' => 999999,
                    'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                    'enabled' => true
                  })['results'].each do |product|
            @existing_products[line[ORGANIZATION]][product['name']] = product['id']

            @api.resource(:repositories)
              .call(:index, {
                      'page_size' => 999999, 'paged' => true,
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'product_id' => product['id'],
                      'enabled' => true,
                      'library' => true
                    })['results'].each do |repository|
              @existing_repositories[line[ORGANIZATION] + product['name']] ||= {}
              @existing_repositories[line[ORGANIZATION] + product['name']][repository['label']] = repository['id']
            end
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          product_id = @existing_products[line[ORGANIZATION]][name]
          if product_id.nil?
            print "Creating product '#{name}'..." if option_verbose?
            if line[REPOSITORY_TYPE] =~ /Red Hat/
              raise "Red Hat product '#{name}' does not exist in '#{line[ORGANIZATION]}'"
            end

            product_id = @api.resource(:products)
              .call(:create, {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'name' => name
                    })['id']
            @existing_products[line[ORGANIZATION]][name] = product_id
          else
            # Nothing to update for products
            print "Updating product '#{name}'..." if option_verbose?
          end
          @existing_repositories[line[ORGANIZATION] + name] = {}
          print "done\n" if option_verbose?

          repository_name = namify(line[REPOSITORY], number)

          if !@existing_repositories[line[ORGANIZATION] + name][repository_name]
            @api.resource(:repositories)
              .call(:index, {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'library' => true,
                      'all' => false,
                      'product_id' => product_id
                    })['results'].each do |repository|
              @existing_repositories[line[ORGANIZATION] + name][repository['name']] = repository
            end
          end

          repository = @existing_repositories[line[ORGANIZATION] + name][repository_name]
          if !repository
            raise "Red Hat product '#{name}' does not have repository '#{repository_name}'" if line[REPOSITORY_TYPE] =~ /Red Hat/

            print "Creating repository '#{repository_name}' in product '#{name}'..." if option_verbose?
            repository = @api.resource(:repositories)
              .call(:create, {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'name' => repository_name,
                      'label' => labelize(repository_name),
                      'product_id' => product_id,
                      'url' => line[REPOSITORY_URL],
                      'content_type' => content_type(line[REPOSITORY_TYPE])
                    })
            @existing_repositories[line[ORGANIZATION] + name][line[LABEL]] = repository
            puts "done" if option_verbose?
          end

          print "Sync'ing repository '#{repository_name}' in product '#{name}'..." if option_verbose?
          if repository['sync_state'] == 'finished'
            puts "already done" if option_verbose?
          else
            if line[REPOSITORY_TYPE] =~ /Red Hat/
              print 'skipping Red Hat repo sync... so slow!... '
            else
              sync_repository(line, repository)
            end
            print "done\n" if option_verbose?
          end
        end

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def content_type(repository_type)
        case repository_type
          when /yum/i
            'yum'
          when /puppet/i
            'puppet'
          else
          raise "Unrecognized repository type '#{repository_type}'"
        end
      end

      def sync_repository(line, repository)
        # TODO: --server needs to come from config/settings
        args = %W{ repository synchronize
                   --id #{ repository['id'] }
                   --organization-id #{ foreman_organization(:name => line[ORGANIZATION]) } }
        hammer.run(args)

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
