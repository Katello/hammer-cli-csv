module HammerCLICsv
  class CsvCommand
    class HostsCommand < BaseCommand
      command_name 'hosts'
      desc         'import or export hosts'

      ORGANIZATION = 'Organization'
      LOCATION = 'Location'
      ENVIRONMENT = 'Puppet Environment'
      OPERATINGSYSTEM = 'Operating System'
      ARCHITECTURE = 'Architecture'
      MACADDRESS = 'MAC Address'
      DOMAIN = 'Domain'
      PARTITIONTABLE = 'Partition Table'
      SUBNET = 'Subnet'
      REALM = 'Realm'
      MEDIUM = 'Medium'
      HOSTGROUP = 'Hostgroup'
      COMPUTERESOURCE = 'Compute Resource'
      COMPUTEPROFILE = 'Compute Profile'
      IMAGE = 'Image'
      ENABLED = 'Enabled'
      MANAGED = 'Managed'

      def export(csv)
        csv << [NAME, ORGANIZATION, LOCATION, ENVIRONMENT, OPERATINGSYSTEM, ARCHITECTURE,
                MACADDRESS, DOMAIN, PARTITIONTABLE, SUBNET, REALM, MEDIUM, HOSTGROUP,
                COMPUTERESOURCE, COMPUTEPROFILE, IMAGE, ENABLED, MANAGED]
        search_options = {:per_page => 999999}
        search_options['search'] = "organization=\"#{option_organization}\"" if option_organization
        @api.resource(:hosts).call(:index, search_options)['results'].each do |host|
          host = @api.resource(:hosts).call(:show, {'id' => host['id']})
          raise "Host 'id=#{host['id']}' not found" if !host || host.empty?

          name = host['name']
          organization = host['organization_name']
          location = host['location_name']
          environment = host['environment_name']
          operatingsystem = host['operatingsystem_name']
          architecture = host['architecture_name']
          mac = host['mac']
          domain = host['domain_name']
          ptable = host['ptable_name']
          subnet = host['subnet_name']
          realm = host['realm_name']
          medium = host['medium_name']
          hostgroup = host['hostgroup_name']
          compute_resource = host['compute_resource_name']
          compute_profile = host['compute_profile_name']
          image = host['image_name']

          enabled = host['enabled'] ? 'Yes' : 'No'
          managed = host['managed'] ? 'Yes' : 'No'

          csv << [name, organization, location, environment, operatingsystem, architecture,
                  mac, domain, ptable, subnet, realm, medium, hostgroup, compute_resource,
                  compute_profile, image, enabled, managed]
        end
      end

      def import
        @existing = {}
        @api.resource(:hosts).call(:index, {:per_page => 999999})['results'].each do |host|
          @existing[host['name']] = host['id'] if host
        end

        thread_import do |line|
          create_hosts_from_csv(line)
        end
      end

      def create_hosts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating host '#{name}'..." if option_verbose?
            @api.resource(:hosts).call(:create, {
                'host' => {
                  'name' => name,
                  'root_pass' => 'changeme',
                  'mac' => namify(line[MACADDRESS], number),
                  'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                  'location_id' => foreman_location(:name => line[LOCATION]),
                  'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                  'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                  'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                  'domain_id' => foreman_domain(:name => line[DOMAIN]),
                  'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                }
            })
          else
            print "Updating host '#{name}'..." if option_verbose?
            @api.resource(:hosts).call(:update, {
                'id' => @existing[name],
                'host' => {
                  'name' => name,
                  'mac' => namify(line[MACADDRESS], number),
                  'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                  'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                  'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                  'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                  'domain_id' => foreman_domain(:name => line[DOMAIN]),
                  'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                }
            })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
