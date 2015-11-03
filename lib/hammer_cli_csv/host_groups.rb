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

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, PARENT, ORGANIZATIONS, LOCATIONS, SUBNET, DOMAIN, OPERATING_SYSTEM,
                  ENVIRONMENT, COMPUTE_PROFILE, PARTITION_TABLE, MEDIUM, ARCHITECTURE, REALM,
                  PUPPET_PROXY, PUPPET_CA_PROXY, CONTENT_SOURCE]
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
            # TODO: http://projects.theforeman.org/issues/7597
            # content_source = hostgroup['content_source_id'] ? foreman_host(:id => hostgroup['content_source_id']) : nil
            content_source = nil
            parent = hostgroup['ancestry'] ? foreman_hostgroup(:id => hostgroup['ancestry']) : nil

            csv << [name, parent, organizations, locations, subnet, domain, operating_system,
                    puppet_environment, compute_profile, partition_table, medium, architecture,
                    realm, puppet_proxy, puppet_ca_proxy, content_source]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:hostgroups).call(:index, {:per_page => 999999})['results'].each do |host|
          @existing[host['name']] = host['id'] if host
        end

        thread_import do |line|
          create_hosts_from_csv(line)
        end
      end

      def create_hosts_from_csv(line)
        return if option_organization && !CSV.parse_line(line[ORGANIZATIONS], {:skip_blanks => true}).include?(option_organization)

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating host group '#{name}'..." if option_verbose?
            # @api.resource(:hosts).call(:create, {
            #     'host' => {
            #       'name' => name,
            #       'root_pass' => 'changeme',
            #       'mac' => namify(line[MACADDRESS], number),
            #       'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            #       'location_id' => foreman_location(:name => line[LOCATION]),
            #       'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
            #       'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
            #       'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
            #       'domain_id' => foreman_domain(:name => line[DOMAIN]),
            #       'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
            #     }
            # })
          else
            print "Updating host '#{name}'..." if option_verbose?
            # @api.resource(:hosts).call(:update, {
            #     'id' => @existing[name],
            #     'host' => {
            #       'name' => name,
            #       'mac' => namify(line[MACADDRESS], number),
            #       'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            #       'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
            #       'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
            #       'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
            #       'domain_id' => foreman_domain(:name => line[DOMAIN]),
            #       'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
            #     }
            # })
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
