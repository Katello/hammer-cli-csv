# Copyright (c) 2013-2014 Red Hat
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
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
require 'katello_api'
require 'foreman_api'
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
        @f_host_api.index({:per_page => 999999})[0]['results'].each do |host|
          host = @f_host_api.show({'id' => host['id']})[0]
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
      @f_host_api.index({:per_page => 999999})[0]['results'].each do |host|
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
          @f_host_api.create({
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
        else
          print "Updating host '#{name}'..." if option_verbose?
          @f_host_api.update({
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
