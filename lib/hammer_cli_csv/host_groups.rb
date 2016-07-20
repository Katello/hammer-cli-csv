module HammerCLICsv
  class CsvCommand
    class HostGroupsCommand < BaseCommand
      command_name 'host-groups'
      desc         'import or export host-groups'

      PARENT = 'Parent Host Group'
      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      SUBNET = 'Subnet'
      DOMAIN = 'Domain'
      OPERATING_SYSTEM = 'Operating System'
      ENVIRONMENT = 'Puppet Environment'
      COMPUTE_PROFILE = 'Compute Profile'
      PARTITION_TABLE = 'Partition Table'
      MEDIUM = 'Medium'
      ARCHITECTURE = 'Architecture'
      REALM = 'Realm'
      PUPPET_PROXY = 'Puppet Proxy'
      PUPPET_CA_PROXY = 'Puppet CA Proxy'
      CONTENT_SOURCE = 'Content Source'
      PASSWORD = 'Password'
      PUPPET_CLASSES = 'Puppet Classes'

      def export(csv)
        csv << [NAME, PARENT, ORGANIZATIONS, LOCATIONS, SUBNET, DOMAIN, OPERATING_SYSTEM,
                ENVIRONMENT, COMPUTE_PROFILE, PARTITION_TABLE, MEDIUM, ARCHITECTURE, REALM,
                PUPPET_PROXY, PUPPET_CA_PROXY, CONTENT_SOURCE, PASSWORD, PUPPET_CLASSES]
        search_options = {:per_page => 999999}
        search_options['search'] = "organization=\"#{option_organization}\"" if option_organization
        @api.resource(:hostgroups).call(:index, search_options)['results'].each do |hostgroup|
          hostgroup = @api.resource(:hostgroups).call(:show, {'id' => hostgroup['id']})
          raise "Host Group 'id=#{hostgroup['id']}' not found" if !hostgroup || hostgroup.empty?

          name = hostgroup['name']
          organizations = export_column(hostgroup, 'organizations', 'name')
          locations = export_column(hostgroup, 'locations', 'name')
          subnet = hostgroup['subnet_name']
          operating_system = hostgroup['operatingsystem_name']
          domain = hostgroup['domain_name']
          puppet_environment = hostgroup['environment_name']
          compute_profile = hostgroup['compute_profile_name']
          partition_table = hostgroup['ptable_name']
          medium = hostgroup['medium_name']
          architecture = hostgroup['architecture_name']
          realm = hostgroup['realm_name']
          puppet_proxy = hostgroup['puppet_proxy_id'] ? foreman_host(:id => hostgroup['puppet_proxy_id']) : nil
          puppet_ca_proxy = hostgroup['puppet_ca_proxy_id'] ? foreman_host(:id => hostgroup['puppet_ca_proxy_id']) : nil
          content_source = hostgroup['content_source_id'] ? foreman_host(:id => hostgroup['content_source_id']) : nil
          parent = hostgroup['ancestry'] ? foreman_hostgroup(:id => hostgroup['ancestry']) : nil
          password = nil
          puppet_classes = export_column(hostgroup, 'puppetclasses') do |puppet_class|
            "#{puppet_class['module_name']}/#{puppet_class['name']}"
          end

          # TODO: http://projects.theforeman.org/issues/6273
          # API call to get the smart class variable override values

          csv << [name, parent, organizations, locations, subnet, domain, operating_system,
                  puppet_environment, compute_profile, partition_table, medium, architecture,
                  realm, puppet_proxy, puppet_ca_proxy, content_source, password, puppet_classes]
        end
      end

      def import
        @existing = {}
        @api.resource(:hostgroups).call(:index, {:per_page => 999999})['results'].each do |host_group|
          @existing[host_group['name']] = host_group['id'] if host_group
        end

        thread_import do |line|
          create_from_csv(line)
        end
      end

      def create_from_csv(line)
        return if option_organization && !CSV.parse_line(line[ORGANIZATIONS], {:skip_blanks => true}).include?(option_organization)

        params = {
          'hostgroup' => {
            'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
            'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATING_SYSTEM]),
            'medium_id' => foreman_medium(:name => line[MEDIUM]),
            'ptable_id' => foreman_partitiontable(:name => line[PARTITION_TABLE]),
            'root_pass' => line[PASSWORD],
            'organization_ids' => collect_column(line[ORGANIZATIONS]) do |organization|
              foreman_organization(:name => organization)
            end,
            'location_ids' => collect_column(line[LOCATIONS]) do |location|
              foreman_location(:name => location)
            end
          }
        }

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          params['hostgroup']['name'] = name

          if !@existing.include? name
            print "Creating host group '#{name}'..." if option_verbose?
            hostgroup = @api.resource(:hostgroups).call(:create, params)
            @existing[name] = hostgroup['id']
          else
            print "Updating host '#{name}'..." if option_verbose?
            params['id'] = @existing[name]
            hostgroup = @api.resource(:hostgroups).call(:update, params)
          end

          # TODO: puppet classes
          puppetclass_ids = collect_column(line[PUPPET_CLASSES]) do |puppet_class|
            module_name, name = puppet_class.split('/')
            foreman_puppet_class(:name => name)
          end
          existing_ids = hostgroup['puppet_classes'].collect { |puppet_class| puppet_class['id'] }
          # DELETE existing_ids - puppetclass_ids
          # POST puppetclass_ids - existing_ids

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
