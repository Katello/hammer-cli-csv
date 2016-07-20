module HammerCLICsv
  class CsvCommand
    class SyncPlansCommand < BaseCommand
      command_name 'sync-plans'
      desc         'import or export repository sync plans'

      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      ENABLED = 'Enabled'
      STARTDATE = 'Start Date'
      INTERVAL = 'Interval'
      PRODUCTS = 'Products'

      def export(csv)
        csv << [NAME, ORGANIZATION, DESCRIPTION, ENABLED, STARTDATE, INTERVAL, PRODUCTS]

        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          @api.resource(:sync_plans).call(:index, {
               'per_page' => 999999,
               'organization_id' => foreman_organization(:name => organization['name'])
          })['results'].each do |sync_plan|
            name = sync_plan['name']
            organization_name = organization['name']
            description = sync_plan['description']
            enabled = sync_plan['enabled'] ? 'Yes' : 'No'
            start_date = sync_plan['sync_date']
            interval = sync_plan['interval']
            products = CSV.generate do |column|
              column << sync_plan['products'].collect do |product|
                product['name']
              end
            end
            products.delete!("\n")
            csv << [name, organization_name, description, enabled, start_date, interval,
                    products]
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_content_hosts_from_csv(line)
        end
      end

      def create_content_hosts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          @api.resource(:sync_plans).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION])
          })['results'].each do |sync_plan|
            @existing[line[ORGANIZATION]][sync_plan['name']] = sync_plan['id']
          end
        end

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          if !@existing[line[ORGANIZATION]].include? name
            print "Creating sync plan '#{name}'..." if option_verbose?
            @api.resource(:sync_plans).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => name,
                'description' => line[DESCRIPTION],
                'enabled' => line[ENABLED] == 'Yes' ? true : false,
                'sync_date' => line[STARTDATE],
                'interval' => line[INTERVAL],
                'products' => products(line)
            })
          else
            print "Updating sync plan '#{name}'..." if option_verbose?
            # TODO
            # @api.resource(:host_collections).call(:update, {
            #     'organization_id' => line[ORGANIZATION],
            #     'id' => @existing[line[ORGANIZATION]][name],
            #     'name' => name,
            #     'max_systems' => (line[LIMIT] == 'Unlimited') ? -1 : line[LIMIT],
            #     'description' => line[DESCRIPTION]
            # })
          end
          puts "done" if option_verbose?
        end

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def products(line)
        return nil if !line[PRODUCTS] || line[PRODUCTS].empty?
        CSV.parse_line(line[PRODUCTS]).collect do |name|
          katello_product(line[ORGANIZATION], :name => name)
        end
      end

    end
  end
end
