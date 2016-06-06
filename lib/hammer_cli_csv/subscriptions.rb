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
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, ORGANIZATION, MANIFEST, CONTENT_SET, ARCH, RELEASE]
          @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization
            export_manifest(csv, organization)
            @api.resource(:products).call(:index, {
                'per_page' => 999999,
                'organization_id' => organization['id'],
                'enabled' => true
            })['results'].each do |product|
              product = @api.resource(:products).call(:show, {:id => product['id']})
              if product['redhat']
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
                    csv << [name, organization['name'], nil, content_set, arch, release]
                  end
                end
              end
            end
          end
        end
      end

      def export_manifest(csv, organization)
        @api.resource(:subscriptions).call(:index, {
            'per_page' => 999999,
            'organization_id' => organization['id']
        })['results'].each do |subscription|
          next if subscription['product_id'].to_i != 0  # Red Hat subs do not have number SKU
          details = "#{subscription['quantity']}|#{subscription['product_id']}|" \
            "#{subscription['name']}|" \
            "#{subscription['contract_number']}|#{subscription['account_number']}"
          csv << ["# Manifest Subscription", organization['name'], nil, nil, nil, details]
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

      # FIXME: TODO remove this rubocop
      # rubocop:disable CyclomaticComplexity
      def enable_products_from_csv(line)
        organization = line[ORGANIZATION] || option_organization
        raise "Organization is required in either input CSV or by option --organization" if organization.nil? || organization.empty?
        line[ORGANIZATION] = organization
        return if option_organization && line[ORGANIZATION] != option_organization

        results = @api.resource(:products).call(:index, {
            'per_page' => 999999,
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'name' => line[NAME]
        })['results']
        raise "No match for product '#{line[NAME]}'" if results.length == 0
        raise "Multiple matches for product '#{line[NAME]}'" if results.length != 1
        product = @api.resource(:products).call(:show, {'id' => results[0]['id']})

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
          if line[RELEASE].nil? || line[RELEASE].empty?
            repo['name'].end_with?("#{line[ARCH]}")
          else
            repo['name'].end_with?("#{line[ARCH]} #{line[RELEASE]}")
          end
        end

        if repository.nil?
          print "Enabling repository #{line[CONTENT_SET]} #{line[ARCH]} #{line[RELEASE]}..." if option_verbose?
          product_content = product['product_content'].find do |content|
            content['content']['name'] == line[CONTENT_SET]
          end
          raise "No match for content set '#{line[CONTENT_SET]}'" if !product_content

          params = {
              'id' => product_content['content']['id'],
              'product_id' => product['id'],
              'basearch' => line[ARCH]
          }
          params['releasever'] = line[RELEASE] unless line[RELEASE].nil? || line[RELEASE].empty?

          @api.resource(:repository_sets).call(:enable, params)
          puts 'done' if option_verbose?
        else
          puts "Repository #{repository['name']} already enabled" if option_verbose?
        end
      end

      def import_manifest_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization
        args = %W{
          --server #{ @server } --username #{ @username } --password #{ @password }
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
