# Copyright 2013-2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class SubnetsCommand < BaseCommand
      command_name 'subnets'
      desc 'import or export subnets'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      NETWORK = 'Network'
      NETWORK_MASK = 'Network Mask'
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

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, NETWORK, NETWORK_MASK,
                  NETWORK_FROM, NETWORK_TO, DOMAINS, GATEWAY, DHCP_PROXY, TFTP_PROXY, DNS_PROXY,
                  DNS_PRIMARY, DNS_SECONDARY, VLAN_ID]
          @api.resource(:subnets).call(:index, {:per_page => 999999})['results'].each do |subnet|
            subnet = @api.resource(:subnets).call(:show, {'id' => subnet['id']})

            name = subnet['name']
            count = 1
            organizations = export_column(subnet, 'organizations', 'name')
            locations = export_column(subnet, 'locations', 'name')
            network = subnet['network']
            network_mask = subnet['mask']
            network_from = subnet['from']
            network_to = subnet['to']
            domains = export_column(subnet, 'domains', 'name')
            gateway = subnet['gateway']
            dhcp_proxy = (subnet['dhcp'] && subnet['dhcp'].has_key?('name')) ? subnet['dhcp']['name'] : ''
            tftp_proxy = (subnet['tftp'] && subnet['tftp'].has_key?('name')) ? subnet['tftp']['name'] : ''
            dns_proxy = (subnet['dns'] && subnet['dns'].has_key?('name')) ? subnet['dns']['name'] : ''
            dns_primary = subnet['dns_primary']
            dns_secondary = subnet['dns_secondary']
            vlan_id = subnet['vlanid']
      csv << [name, count, organizations, locations, network, network_mask,
              network_from, network_to, domains, gateway, dhcp_proxy, tftp_proxy, dns_proxy,
              dns_primary, dns_secondary, vlan_id]
          end
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
        line[DOMAINS] = (CSV.parse_line(line[DOMAINS]) || []).collect do |domain|
          foreman_domain(:name => domain)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating subnet '#{name}'..." if option_verbose?
            id = @api.resource(:subnets)
              .call(:create, {
                      'subnet' => {
                        'name' => name,
                      }
                    })['id']
          else
            print "Updating subnet '#{name}'..." if option_verbose?
            id = @api.resource(:subnets)
              .call(:update, {
                      'id' => @existing[name],
                      'subnet' => {
                        'name' => name,
                        'network' => line[NETWORK],
                        'mask' => line[NETWORK_MASK],
                        'from' => line[NETWORK_FROM],
                        'to' => line[NETWORK_TO],
                        'domain_ids' => line[DOMAINS]
                      }
                    })['id']
          end

          # Update associated resources
          associate_organizations(id, line[ORGANIZATIONS], 'subnet')
          associate_locations(id, line[LOCATIONS], 'subnet')

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
