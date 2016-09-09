module HammerCLICsv
  class CsvCommand
    class SubnetsCommand < BaseCommand
      command_name 'subnets'
      desc 'import or export subnets'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      NETWORK = 'Network'
      NETWORK_MASK = 'Network Mask'
      NETWORK_PREFIX = 'Network Prefix'
      NETWORK_FROM = 'From'
      NETWORK_TO = 'To'
      DOMAINS = 'Domains'
      GATEWAY = 'Gateway'
      DHCP_PROXY = 'DHCP Proxy'
      TFTP_PROXY = 'TFTP Proxy'
      DNS_PROXY = 'DNS Proxy'
      DNS_PRIMARY = 'DNS Primary'
      DNS_SECONDARY = 'DNS Secondary'
      VLAN_ID = 'VLAN ID'

      def export(csv)
        csv << [NAME, ORGANIZATIONS, LOCATIONS, NETWORK, NETWORK_MASK, NETWORK_PREFIX,
                NETWORK_FROM, NETWORK_TO, DOMAINS, GATEWAY, DHCP_PROXY, TFTP_PROXY, DNS_PROXY,
                DNS_PRIMARY, DNS_SECONDARY, VLAN_ID]
        @api.resource(:subnets).call(:index, {:per_page => 999999})['results'].each do |subnet|
          subnet = @api.resource(:subnets).call(:show, {'id' => subnet['id']})

          name = subnet['name']
          organizations = export_column(subnet, 'organizations', 'name')
          locations = export_column(subnet, 'locations', 'name')
          network = subnet['network']
          network_mask = subnet['mask']
          network_prefix = subnet['cidr']
          network_from = subnet['from']
          network_to = subnet['to']
          domains = export_column(subnet, 'domains', 'name')
          gateway = subnet['gateway']
          dhcp_proxy = (subnet['dhcp'] && subnet['dhcp'].key?('name')) ? subnet['dhcp']['name'] : ''
          tftp_proxy = (subnet['tftp'] && subnet['tftp'].key?('name')) ? subnet['tftp']['name'] : ''
          dns_proxy = (subnet['dns'] && subnet['dns'].key?('name')) ? subnet['dns']['name'] : ''
          dns_primary = subnet['dns_primary']
          dns_secondary = subnet['dns_secondary']
          vlan_id = subnet['vlanid']
          csv << [name, organizations, locations, network, network_mask, network_prefix,
                  network_from, network_to, domains, gateway, dhcp_proxy, tftp_proxy, dns_proxy,
                  dns_primary, dns_secondary, vlan_id]
        end
      end

      def import
        @existing = {}
        @api.resource(:subnets).call(:index, {:per_page => 999999})['results'].each do |subnet|
          @existing[subnet['name']] = subnet['id'] if subnet
        end

        thread_import do |line|
          create_subnets_from_csv(line)
        end
      end

      def create_subnets_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        line[DOMAINS] = (CSV.parse_line(line[DOMAINS]) || []).collect do |domain|
          foreman_domain(:name => domain)
        end

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          params = {
            'subnet' => {
              'name' => name,
              'network' => line[NETWORK],
              'mask' => line[NETWORK_MASK],
              'from' => line[NETWORK_FROM],
              'to' => line[NETWORK_TO],
              'domain_ids' => line[DOMAINS],
              'tftp_id' => foreman_smart_proxy(:name => line[TFTP_PROXY]),
              'dns_id' => foreman_smart_proxy(:name => line[DNS_PROXY]),
              'dhcp_id' => foreman_smart_proxy(:name => line[DHCP_PROXY])
            }
          }
          if !@existing.include? name
            print _("Creating subnet '%{name}'...") % {:name => name} if option_verbose?
            id = @api.resource(:subnets).call(:create, params)['id']
          else
            print _("Updating subnet '%{name}'...") % {:name => name} if option_verbose?
            params['id'] = @existing[name]
            id = @api.resource(:subnets).call(:update, params)['id']
          end

          associate_organizations(id, line[ORGANIZATIONS], 'subnet')
          associate_locations(id, line[LOCATIONS], 'subnet')

          puts _("done") if option_verbose?
        end
      end
    end
  end
end
