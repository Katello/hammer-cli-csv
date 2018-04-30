module HammerCLICsv
  class CsvCommand
    class ProductsCommand < BaseCommand
      command_name 'products'
      desc         _('import or export products')

      option %w(--[no-]sync), :flag, _('Sync product repositories (default true)'), :default => true
      LABEL = 'Label'
      ORGANIZATION = 'Organization'
      REPOSITORY = 'Repository'
      REPOSITORY_TYPE = 'Repository Type'
      CONTENT_SET = 'Content Set'
      RELEASEVER = '$releasever'
      BASEARCH = '$basearch'
      REPOSITORY_URL = 'Repository Url'
      DESCRIPTION = 'Description'
      VERIFY_SSL = 'Verify SSL'
      UPSTREAM_USERNAME = 'Username'
      UPSTREAM_PASSWORD = 'Password'
      DOWNLOAD_POLICY = 'Download Policy'
      MIRROR_ON_SYNC = 'Mirror on Sync'
      UNPROTECTED = 'Publish via HTTP'

      def export(csv)
        csv << [NAME, LABEL, ORGANIZATION, DESCRIPTION, REPOSITORY, REPOSITORY_TYPE,
                CONTENT_SET, BASEARCH, RELEASEVER, REPOSITORY_URL, VERIFY_SSL, UNPROTECTED, MIRROR_ON_SYNC, DOWNLOAD_POLICY,
                UPSTREAM_USERNAME, UPSTREAM_PASSWORD]
        @api.resource(:organizations).call(:index, {
            :per_page => 999999,
            :search => option_search
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
              repository = @api.resource(:repositories).call(:show, {:id => repository['id']})
              if repository['product_type'] == 'custom'
                repository_type = "Custom #{repository['content_type'].capitalize}"
                if repository['content_type'] == 'docker'
                  content_set = repository['docker_upstream_name']
                else
                  content_set = nil
                end
              else
                repository_type = "Red Hat #{repository['content_type'].capitalize}"
                content_set = get_content_set(organization, product, repository)
              end
              releasever = repository['minor']
              basearch = nil
              csv << [product['name'], product['label'], organization['name'],
                      product['description'], repository['name'], repository_type,
                      content_set, basearch, releasever, repository['url'],
                      repository['verify_ssl_on_sync'] ? 'Yes' : 'No',
                      repository['unprotected'] ? 'Yes' : 'No',
                      repository['mirror_on_sync'] ? 'Yes' : 'No', repository['download_policy'],
                      repository['upstream_username'],nil]
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
        return if option_organization && line[ORGANIZATION] != option_organization

        count(line[COUNT]).times do |number|
          product = create_or_update_product(line, number)
          create_or_update_repository(line, number, product)
          puts _('done') if option_verbose?
        end

      end

      private

      def create_or_update_product(line, number)
        product_name = namify(line[NAME], number)
        product_label = labelize(namify(line[LABEL] || line[NAME], number))
        get_existing_product(product_name, line)
        if line[REPOSITORY_TYPE] =~ /Red Hat/
          product = enable_red_hat_product(line, product_name)
        else
          params = {
            :name => product_name,
            :label => product_label,
            'organization_id' => foreman_organization(:name => line[ORGANIZATION])
          }
          params[:description] = line[DESCRIPTION] if !line[DESCRIPTION].nil? &&
                                                      !line[DESCRIPTION].empty?
          product = @existing_products[line[ORGANIZATION]][product_name]
          if product.nil?
            print _("Creating product '%{name}'...") % {:name => product_name} if option_verbose?
            product = @api.resource(:products).call(:create, params)
            @existing_products[line[ORGANIZATION]][product_name] = product
          else
            print _("Updating product '%{name}'...") % {:name => product_name} if option_verbose?
            params[:id] = product['id']
            @api.resource(:products).call(:update, params)
          end
        end

        return product
      end

      # rubocop:disable CyclomaticComplexity
      def create_or_update_repository(line, number, product)
        repository_name = namify(line[REPOSITORY], number)
        repository = get_repository(line, product['name'], product['id'], repository_name)

        params = {
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'name' => repository_name,
            'url' => line[REPOSITORY_URL]
        }
        params['verify_ssl'] = line[VERIFY_SSL] == 'Yes' ? true : false if !line[VERIFY_SSL].nil? && !line[VERIFY_SSL].empty?
        params['unprotected'] = line[UNPROTECTED] == 'Yes' ? true : false if !line[UNPROTECTED].nil? && !line[UNPROTECTED].empty?
        params['mirror_on_sync'] = line[MIRROR_ON_SYNC] == 'Yes' ? true : false if !line[MIRROR_ON_SYNC].nil? && !line[MIRROR_ON_SYNC].empty?
        params['download_policy'] = line[DOWNLOAD_POLICY] if !line[DOWNLOAD_POLICY].nil? && !line[DOWNLOAD_POLICY].empty?
        params['upstream_username'] = line[UPSTREAM_USERNAME] if !line[UPSTREAM_USERNAME].nil? && !line[UPSTREAM_USERNAME].empty?
        params['upstream_password'] = line[UPSTREAM_PASSWORD] if !line[UPSTREAM_PASSWORD].nil? && !line[UPSTREAM_PASSWORD].empty?
        if line[REPOSITORY_TYPE] == 'Custom Docker'
          params['docker_upstream_name'] = line[CONTENT_SET]
        end

        if !repository
          if line[REPOSITORY_TYPE] =~ /Red Hat/
            raise _("Red Hat product '%{product_name}' does not have repository '%{repository_name}'") %
              {:product_name => product['name'], :repository_name => repository_name}
          end
          params['label'] = labelize(repository_name)
          params['product_id'] = product['id']
          params['content_type'] = content_type(line[REPOSITORY_TYPE])

          print _("Creating repository '%{repository_name}'...") % {:repository_name => repository_name} if option_verbose?
          repository = @api.resource(:repositories).call(:create, params)
          @existing_repositories[line[ORGANIZATION] + product['name']][repository_name] = repository
        else
          print _("Updating repository '%{repository_name}'...") % {:repository_name => repository_name} if option_verbose?
          params['id'] = repository['id']
          repository = @api.resource(:repositories).call(:update, params)
        end

        sync_repository(line, product['name'], repository)
      end
      # rubocop:enable CyclomaticComplexity

      def get_existing_product(product_name, line)
        @existing_products[line[ORGANIZATION]] = {}
        @api.resource(:products).call(:index, {
            'per_page' => 999999,
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'enabled' => true,
            'search' => "name=\"#{product_name}\""
        })['results'].each do |product|
          @existing_products[line[ORGANIZATION]][product['name']] = product

          @api.resource(:repositories).call(:index, {
              'page_size' => 999999, 'paged' => true,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'product_id' => product['id'],
              'enabled' => true,
              'library' => true
          })['results'].each do |repository|
            @existing_repositories[line[ORGANIZATION] + product['name']] ||= {}
            @existing_repositories[line[ORGANIZATION] + product['name']][repository['name']] = repository
          end
        end
      end

      def get_repository(line, product_name, product_id, repository_name)
        @existing_repositories[line[ORGANIZATION] + product_name] ||= {}
        if !@existing_repositories[line[ORGANIZATION] + product_name][repository_name]
          @api.resource(:repositories).call(:index, {
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'library' => true,
              'all' => false,
              'product_id' => product_id
          })['results'].each do |repository|
            @existing_repositories[line[ORGANIZATION] + product_name][repository['name']] = repository
          end
        end
        @existing_repositories[line[ORGANIZATION] + product_name][repository_name]
      end

      def enable_red_hat_product(line, product_name)
        product = @existing_products[line[ORGANIZATION]][product_name]
        unless product
          product = @api.resource(:products).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'name' => product_name
          })['results'][0]
          raise _("Red Hat product '%{product_name}' does not exist") %
              {:product_name => product_name} if product.nil?
          @existing_repositories[line[ORGANIZATION] + product['name']] = {}
        end
        product = @api.resource(:products).call(:show, {:id => product['id']})

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
          repo['name'] == line[REPOSITORY]
        end

        if repository.nil?
          print _('Enabling repository %{name}...') % {:name => line[REPOSITORY]} if option_verbose?
          product_content = product['product_content'].find do |content|
            content['content']['name'] == line[CONTENT_SET]
          end
          raise "No match for content set '#{line[CONTENT_SET]}'" if !product_content

          basearch,releasever = parse_basearch_releasever(line)
          params = {
              'id' => product_content['content']['id'],
              'product_id' => product['id']
          }
          params['basearch'] = basearch if !basearch.nil? && repository_set['contentUrl'] =~ /\$basearch/
          params['releasever'] = releasever if !releasever.nil? && repository_set['contentUrl'] =~ /\$releasever/
          @api.resource(:repository_sets).call(:enable, params)
          puts _('done') if option_verbose?
        else
          puts _('Repository %{name} already enabled') % {:name => repository['name']} if option_verbose?
        end
        product
      end

      # basearch and releasever are required for repo set enable. The repository ends with, for example,
      # "x86_64 6.1" or "ia64 6 Server"
      def parse_basearch_releasever(line)
        basearch = line[BASEARCH] if !line[BASEARCH].nil? && !line[BASEARCH].empty?
        releasever = line[RELEASEVER] if !line[RELEASEVER].nil? && !line[RELEASEVER].empty?
        content_set = line[REPOSITORY]
        pieces = content_set.split
        if pieces[-1] == 'Server'
          basearch = pieces[-3] unless basearch
          releasever = "#{pieces[-2]}#{pieces[-1]}" unless releasever
        else
          basearch = pieces[-2] unless basearch
          releasever = pieces[-1] unless releasever
        end
        return basearch,releasever
      end

      def content_type(repository_type)
        case repository_type
        when /yum/i
          'yum'
        when /puppet/i
          'puppet'
        when /docker/i
          'docker'
        else
          raise "Unrecognized repository type '#{repository_type}'"
        end
      end

      def sync_repository(line, name, repository)
        if (HammerCLI::Settings.get(:csv, :products_sync) == true || HammerCLI::Settings.get(:csv, :products_sync).nil?) &&
            option_sync?
          if option_verbose?
            print _("syncing repository '%{repository_name}' in product '%{name}'...") %
              {:repository_name => repository['name'], :name => name}
          end
          if repository['last_sync']
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

      end

      def get_content_set(organization, product, repository)
        organization_id = organization['id']
        product_id = product['id']
        @content_sets ||={}
        @content_sets[organization_id] ||= {}
        if @content_sets[organization_id][product_id].nil?
          @content_sets[organization_id][product_id] = {}
          @api.resource(:repository_sets).call(:index, {
              'per_page' => 999999,
              'organization_id' => organization_id,
              'product_id' => product_id
          })['results'].each do |repository_set|
            content_set = repository_set['name']
            repository_set['repositories'].each do |repo|
              @content_sets[organization_id][product_id][repo['id']] = content_set
            end
          end
        end
        content_set = @content_sets[organization_id][product_id][repository['id']]

        raise "Content set for repository '#{repository['name']}' not found in product '#{product['name']}" unless content_set

        content_set
      end
    end
  end
end
