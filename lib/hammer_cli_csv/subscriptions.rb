module HammerCLICsv
  class CsvCommand
    class SubscriptionsCommand < BaseCommand
      command_name 'subscriptions'
      desc         'import or export subscriptions'

      def self.supported?
        true
      end

      ORGANIZATION = 'Organization'
      MANIFEST = 'Manifest File'
      SUBSCRIPTION = 'Subscription Name'
      QUANTITY = 'Quantity'
      SKU = 'Product SKU'
      CONTRACT = 'Contract Number'
      ACCOUNT = 'Account Number'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, ORGANIZATION, MANIFEST, SUBSCRIPTION, QUANTITY, SKU, CONTRACT, ACCOUNT]
          @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization
            organization = @api.resource(:organizations).call(:show, {'id' => organization['id']})
            export_manifest(csv, organization)
            export_subscriptions(csv, organization)
          end
        end
      end

      def export_manifest(csv, organization)
        info = organization['owner_details']['upstreamConsumer']
        return if info.nil?

        csv << ["# Manifest Name", organization['name'], info['name']]
        csv << ["# Manifest URL", organization['name'], "https://#{info['webUrl']}#{info['uuid']}"]
      end

      def export_subscriptions(csv, organization)
        @api.resource(:subscriptions).call(:index, {
            'per_page' => 999999,
            'organization_id' => organization['id']
        })['results'].each do |subscription|
          next if subscription['product_id'].to_i != 0  # Red Hat subs do not have number SKU
          name = subscription['host'].nil? ? "# Subscription" : "# Guest Subscription for Host '#{subscription['host']['name']}'"
          quantity = subscription['quantity'] < 0 ? "Unlimited" : subscription['quantity']
          csv << [name, organization['name'], nil, subscription['name'],
                  quantity, subscription['product_id'], subscription['contract_number'],
                  subscription['account_number'],
                  subscription['start_date'], subscription['end_date']]
        end
      end

      def import
        thread_import do |line|
          if line[MANIFEST] && !line[MANIFEST].empty?
            import_manifest(line)
          end
        end
      end

      def import_manifest(line)
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
