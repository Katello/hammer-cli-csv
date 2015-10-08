module HammerCLICsv
  class CsvCommand
    class DomainsCommand < BaseCommand
      command_name 'domains'
      desc         'import or export domains'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      DESCRIPTION = 'Description'
      SMART_PROXY = 'DNS Smart Proxy'
      PARAMETERS = 'Parameters'

      SEPARATOR = ' = '

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, ORGANIZATIONS, LOCATIONS, DESCRIPTION, SMART_PROXY, PARAMETERS]
          search_options = {:per_page => 999999}
          search_options['search'] = "organization=\"#{option_organization}\"" if option_organization
          @api.resource(:domains).call(:index, search_options)['results'].each do |domain|
            domain = @api.resource(:domains).call(:show, {'id' => domain['id']})
            raise "Domain 'id=#{domain['id']}' not found" if !domain || domain.empty?

            name = domain['name']
            organizations = option_organization ? option_organization : export_column(domain, 'organizations', 'name')
            locations = export_column(domain, 'locations', 'name')
            description = domain['fullname']
            capsule = foreman_smart_proxy(:id => domain['dns_id'])
            parameters = export_parameters(domain['parameters'])
            csv << [name, organizations, locations, description, capsule, parameters]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:domains).call(:index, {:per_page => 999999})['results'].each do |domain|
          @existing[domain['name']] = domain['id'] if domain
        end

        thread_import do |line|
          create_domains_from_csv(line)
        end
      end

      def create_domains_from_csv(line)
        dns_id = foreman_smart_proxy(:name => line[SMART_PROXY])
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          description = namify(line[DESCRIPTION], number)
          if !@existing.include? name
            print "Creating domain '#{name}'..." if option_verbose?
            domain_id = @api.resource(:domains).call(:create, {
                                                       'domain' => {
                                                         'name' => name,
                                                         'fullname' => description,
                                                         'dns_id' => dns_id
                                                       }
                                                     })['id']
          else
            print "Updating domain '#{name}'..." if option_verbose?
            domain_id = @api.resource(:domains).call(:update, {
                                                       'id' => @existing[name],
                                                       'domain' => {
                                                         'name' => name,
                                                         'fullname' => description,
                                                         'dns_id' => dns_id
                                                       }
                                                     })['id']
          end

          # Update associated resources
          domains ||= {}
          CSV.parse_line(line[ORGANIZATIONS]).each do |organization|
            organization_id = foreman_organization(:name => organization)
            if domains[organization].nil?
              domains[organization] = @api.resource(:organizations).call(:show, {'id' => organization_id})['domains'].collect do |domain|
                domain['id']
              end
            end
            domains[organization] += [domain_id] if !domains[organization].include? domain_id

            @api.resource(:organizations).call(:update, {
                                                 'id' => organization_id,
                                                 'organization' => {
                                                   'domain_ids' => domains[organization]
                                                 }
                                               })
          end

          import_parameters(domain_id, line[PARAMETERS])

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def export_parameters(parameters)
        return '' if parameters.nil? || parameters.empty?

        values = CSV.generate do |column|
          column  << parameters.collect do |parameter|
            "#{parameter['name']}#{SEPARATOR}#{parameter['value']}"
          end
        end
        values.delete!("\n")
      end

      def import_parameters(domain_id, parameters)
        collect_column(parameters) do |parameter|
          (parameter_name, parameter_value) = parameter.split(SEPARATOR)

          results = @api.resource(:parameters).call(:index, { :domain_id => domain_id, :search => "name=\"#{parameter_name}\"" })['results']
          if results.empty?
            @api.resource(:parameters).call(:create, {
                                                       'domain_id' => domain_id,
                                                       'parameter' => {
                                                         'name' => parameter_name,
                                                         'value' => parameter_value
                                                       }
                                                     })
          else
            @api.resource(:parameters).call(:create, {
                                                       'id' => results[0]['id'],
                                                       'domain_id' => domain_id,
                                                       'parameter' => {
                                                         'name' => parameter_name,
                                                         'value' => parameter_value
                                                       }
                                                     })
          end
        end
      end
    end
  end
end
