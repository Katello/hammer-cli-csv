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

      def export(csv)
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
          parameters = export_column(domain, 'parameters') do |parameter|
            "#{parameter['name']}#{SEPARATOR}#{parameter['value']}"
          end
          csv << [name, organizations, locations, description, capsule, parameters]
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
          params = {
            'domain' => {
              'name' => name,
              'fullname' => description,
              'dns_id' => dns_id
            }
          }
          if !@existing.include? name
            print _("Creating domain '%{name}'...") % {:name => name} if option_verbose?
            domain = @api.resource(:domains).call(:create, params)
          else
            print _("Updating domain '%{name}'...") % {:name => name} if option_verbose?
            params['id'] = @existing[name]
            domain = @api.resource(:domains).call(:update, params)
          end

          update_organizations(line, domain)
          update_locations(line, domain)
          import_parameters(domain['id'], line[PARAMETERS])

          puts _("done") if option_verbose?
        end
      end

      def update_organizations(line, domain)
        domains ||= {}
        CSV.parse_line(line[ORGANIZATIONS]).each do |organization|
          organization_id = foreman_organization(:name => organization)
          if domains[organization].nil?
            domains[organization] = @api.resource(:organizations).call(:show, {'id' => organization_id})['domains'].collect do |existing_domain|
              existing_domain['id']
            end
          end
          domains[organization] += [domain['id']] if !domains[organization].include? domain['id']

          @api.resource(:organizations).call(:update, {
                                               'id' => organization_id,
                                               'organization' => {
                                                 'domain_ids' => domains[organization]
                                               }
                                             })
        end
      end

      def update_locations(line, domain)
        return if line[LOCATIONS].nil? || line[LOCATIONS].empty?
        domains ||= {}
        CSV.parse_line(line[LOCATIONS]).each do |location|
          location_id = foreman_location(:name => location)
          if domains[location].nil?
            domains[location] = @api.resource(:locations).call(:show, {'id' => location_id})['domains'].collect do |existing_domain|
              existing_domain['id']
            end
          end
          domains[location] += [domain['id']] if !domains[location].include? domain['id']

          @api.resource(:locations).call(:update, {
                                           'id' => location_id,
                                           'location' => {
                                             'domain_ids' => domains[location]
                                           }
                                         })
        end
      end

      def import_parameters(domain_id, parameters)
        collect_column(parameters) do |parameter|
          (parameter_name, parameter_value) = parameter.split(SEPARATOR)

          results = @api.resource(:parameters).call(:index, { :domain_id => domain_id, :search => "name=\"#{parameter_name}\"" })['results']
          params = {
            'domain_id' => domain_id,
            'parameter' => {
              'name' => parameter_name,
              'value' => parameter_value
            }
          }
          if results.empty?
            @api.resource(:parameters).call(:create, params)
          else
            params['id'] = results[0]['id']
            @api.resource(:parameters).call(:update, params)
          end
        end
      end
    end
  end
end
