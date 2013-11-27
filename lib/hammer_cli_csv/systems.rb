# Copyright (c) 2013 Red Hat
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
# -= Systems CSV =-
#
# Columns
#   Name
#     - System name
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
  class SystemsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    ENVIRONMENT = 'Environment'
    CONTENTVIEW = 'Content View'
    VIRTUAL = 'Virtual'
    HOST = 'Host'
    OPERATINGSYSTEM = 'OS'
    ARCHITECTURE = 'Arch'
    SOCKETS = 'Sockets'
    RAM = 'RAM'
    CORES = 'Cores'
    SLA = 'SLA'
    PRODUCTS = 'Products'
    SUBSCRIPTIONS = 'Subscriptions'

    def execute
      super
      csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, ORGANIZATION, ENVIRONMENT, OPERATINGSYSTEM, ARCHITECTURE, MACADDRESS, DOMAIN, PARTITIONTABLE]
        @f_host_api.index({:per_page => 999999}, HEADERS)[0].each do |host|
          host = @f_host_api.show({'id' => host['id']}, HEADERS)[0]
          raise RuntimeError.new("Host 'id=#{host['id']}' not found") if !host || host.empty?

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

      thread_import do |line|
        create_systems_from_csv(line)
      end
    end

    def create_systems_from_csv(line)

      @k_system_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true}, HEADERS)[0]['results'].each do |system|
        @existing[line[ORGANIZATION]] ||= {}
        puts "#####'#{system}'"
        @existing[line[ORGANIZATION]][system['name']] = system['id'] unless system.nil? || system.empty?
      end

      puts @existing
      puts katello_environment(:organization => line[ORGANIZATION], :name => line[ENVIRONMENT])

      return

      facts = {}
      facts['cpu.core(s)_per_socket'] = line[CORES]
      facts['cpu.cpu_socket(s)'] = line[SOCKETS]
      facts['memory.memtotal'] = line[RAM]
      facts['uname.machine'] = line[ARCH]
      if line[OS].index(' ')
        (facts['distribution.name'], facts['distribution.version']) = line[OS].split(' ')
      else
        (facts['distribution.name'], facts['distribution.version']) = ['RHEL', line[OS]]
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating system '#{name}'..." if verbose?
          @k_system_api.create({
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
                           }, HEADERS)
          print "done\n" if verbose?
        else
          print "Updating host '#{name}'..." if verbose?
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
                             }, HEADERS)
          print "done\n" if verbose?
        end
      end
    rescue RuntimeError => e
      raise RuntimeError.new("#{e}\n       #{line}")
    end
  end

  HammerCLI::MainCommand.subcommand("csv:systems", "import/export systems", HammerCLICsv::SystemsCommand)
end
