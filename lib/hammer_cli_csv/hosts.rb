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

#
# -= Hosts CSV =-
#
# Columns
#   Name
#     - Host name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   MAC Address
#     - MAC address
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "FF:FF:FF:FF:FF:%02x" -> "FF:FF:FF:FF:FF:0A"
#     - Warning: be sure to keep count below 255 or MAC hex will exceed limit
#

require 'hammer_cli'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class HostsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    ENVIRONMENT = 'Environment'
    OPERATINGSYSTEM = 'Operating System'
    ARCHITECTURE = 'Architecture'
    MACADDRESS = 'MAC Address'
    DOMAIN = 'Domain'
    PARTITIONTABLE = 'Partition Table'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, ORGANIZATION, ENVIRONMENT, OPERATINGSYSTEM, ARCHITECTURE, MACADDRESS, DOMAIN, PARTITIONTABLE]
        @api.resource(:hosts).call(:index, {:per_page => 999999})['results'].each do |host|
          host = @api.resource(:hosts).call(:show, {'id' => host['id']})
          raise "Host 'id=#{host['id']}' not found" if !host || host.empty?

          name = host['name']
          count = 1
          organization = foreman_organization(:id => host['organization_id'])
          environment = foreman_environment(:id => host['environment_id'])
          operatingsystem = foreman_operatingsystem(:id => host['operatingsystem_id'])
          architecture = foreman_architecture(:id => host['architecture_id'])
          mac = host['mac']
          domain = foreman_domain(:id => host['domain_id'])
          ptable = foreman_partitiontable(:id => host['ptable_id'])

          csv << [name, count, organization, environment, operatingsystem, architecture, mac, domain, ptable]
        end
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
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating host '#{name}'..." if option_verbose?
          @api.resource(:hosts).call(:create, {
                             'host' => {
                               'name' => name,
                               'root_pass' => 'changeme',
                               'mac' => namify(line[MACADDRESS], number),
                               'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                               'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                               'operatingsystem_id' => foreman_operatingsystem(:name => line[OPERATINGSYSTEM]),
                               'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
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
                                 'environment_id' => foreman_environment(:name => line[ENVIRONMENT]),
                                 'architecture_id' => foreman_architecture(:name => line[ARCHITECTURE]),
                                 'domain_id' => foreman_domain(:name => line[DOMAIN]),
                                 'ptable_id' => foreman_partitiontable(:name => line[PARTITIONTABLE])
                               }
                             })
        end
        print "done\n" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:hosts", "import/export hosts", HammerCLICsv::HostsCommand)
end
