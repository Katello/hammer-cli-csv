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
      desc         _('import or export products')

      option %w(--organization), 'ORGANIZATION', _('Only process organization matching this name')
      option %w(--sync), 'true|false', _('Sync product repositories (default true)')

      LABEL = 'Label'
      ORGANIZATION = 'Organization'
      REPOSITORY = 'Repository'
      REPOSITORY_TYPE = 'Repository Type'
      REPOSITORY_URL = 'Repository Url'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, LABEL, ORGANIZATION, REPOSITORY, REPOSITORY_TYPE, REPOSITORY_URL]
          @api.resource(:organizations).call(:index, {
              :per_page => 999999
          })['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization
            @api.resource(:products).call(:index, {
                'per_page' => 999999,
                'enabled' => true,
                'organization_id' => organization['id']
            })['results'].each do |product|
              @api.resource(:repositories).call(:index, {
                  'product_id' => product['id'],
                  'organization_id' => organization['id']
              })['results'].each do |repository|
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

      # FIXME: TODO remove this rubocop
      # rubocop:disable CyclomaticComplexity
      def create_products_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        if !@existing_products[line[ORGANIZATION]]
          @existing_products[line[ORGANIZATION]] = {}
          @api.resource(:products).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'enabled' => true
          })['results'].each do |product|
            @existing_products[line[ORGANIZATION]][product['name']] = product['id']

            @api.resource(:repositories).call(:index, {
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
            print _("Creating product '%{name}'...") % {:name => name} if option_verbose?
            if line[REPOSITORY_TYPE] =~ /Red Hat/
              raise _("Red Hat product '%{name}' does not exist in '%{organization}'") %
                {:name => name, :organization => line[ORGANIZATION]}
            end

            product_id = @api.resource(:products).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => name
            })['id']
            @existing_products[line[ORGANIZATION]][name] = product_id
          else
            # Nothing to update for products
            print _("Updating product '%{name}'...") % {:name => name} if option_verbose?
          end
          @existing_repositories[line[ORGANIZATION] + name] = {}

          repository_name = namify(line[REPOSITORY], number)

          if !@existing_repositories[line[ORGANIZATION] + name][repository_name]
            @api.resource(:repositories).call(:index, {
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

            if option_verbose?
              print _("Creating repository '%{repository_name}' in product '%{name}'...") %
                {:repository_name => repository_name, :name => name}
            end
            repository = @api.resource(:repositories).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => repository_name,
                'label' => labelize(repository_name),
                'product_id' => product_id,
                'url' => line[REPOSITORY_URL],
                'content_type' => content_type(line[REPOSITORY_TYPE])
            })
            @existing_repositories[line[ORGANIZATION] + name][line[LABEL]] = repository
          end

          sync_repository(line, repository)
          puts _('done') if option_verbose?
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
        if option_sync =~ (/A(true|1|yes)$/i) || HammerCLI::Settings.get(:csv, :products_sync) ||
              (option_sync.nil? && HammerCLI::Settings.get(:csv, :products_sync).nil?)
          if option_verbose?
            print _("syncing repository '%{repository_name}' in product '%{name}'...") %
              {:repository_name => repository_name, :name => name}
          end
          if repository['sync_state'] == 'finished'
            print _("previously synced, skipping...") if option_verbose?
          else
            exec_sync_repository(line, repository)
          end
        end
      end

      def exec_sync_repository(line, repository)
        args = %W{ --server #{ @server } --username #{ @username } --password #{ @password }
                   repository synchronize
                   --id #{ repository['id'] }
                   --organization-id #{ foreman_organization(:name => line[ORGANIZATION]) } }
        hammer.run(args)

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
