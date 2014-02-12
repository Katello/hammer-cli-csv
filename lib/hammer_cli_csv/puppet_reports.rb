# Copyright (c) 2014 Red Hat
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
  class PuppetReportsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    ENVIRONMENT = 'Environment'
    CONTENTVIEW = 'Content View'
    SYSTEMGROUPS = 'System Groups'
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

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
        csv << [NAME, COUNT, ORGANIZATION, ENVIRONMENT, CONTENTVIEW, SYSTEMGROUPS, VIRTUAL, HOST,
               OPERATINGSYSTEM, ARCHITECTURE, SOCKETS, RAM, CORES, SLA, PRODUCTS, SUBSCRIPTIONS]
        @k_organization_api.index({:per_page => 999999})[0]['results'].each do |organization|
          @k_system_api.index({
                                'per_page' => 999999,
                                'organization_id' => organization['label']
                               })[0]['results'].each do |system|
            system = @k_system_api.show({
                                          'id' => system['uuid'],
                                          'fields' => 'full'
                                        })[0]

            name = system['name']
            count = 1
            organization_label = organization['label']
            environment = system['environment']['label']
            contentview = system['content_view']['name']
            systemgroups = CSV.generate do |column|
              column << system['systemGroups'].collect do |systemgroup|
                systemgroup['name']
              end
            end.delete!("\n")
            virtual = system['facts']['virt.is_guest'] == 'true' ? 'Yes' : 'No'
            host = system['host']
            operatingsystem = "#{system['facts']['distribution.name']} " if system['facts']['distribution.name']
            operatingsystem += system['facts']['distribution.version'] if system['facts']['distribution.version']
            architecture = system['facts']['uname.machine']
            sockets = system['facts']['cpu.cpu_socket(s)']
            ram = system['facts']['memory.memtotal']
            cores = system['facts']['cpu.core(s)_per_socket']
            sla = ""
            products = CSV.generate do |column|
              column << system['installedProducts'].collect do |product|
                "#{product['productId']}|#{product['productName']}"
              end
            end.delete!("\n")
            subscriptions = CSV.generate do |column|
              column << @k_subscription_api.index({
                                                    'system_id' => system['uuid']
                                                  })[0]['results'].collect do |subscription|
                "#{subscription['product_id']}|#{subscription['product_name']}"
              end
            end.delete!("\n")
            csv << [name, count, organization_label, environment, contentview, systemgroups, virtual, host,
                    operatingsystem, architecture, sockets, ram, cores, sla, products, subscriptions]
          end
        end
      end
    end

    def import
      @existing = {}
      @host_guests = {}

      thread_import do |line|
        create_systems_from_csv(line)
      end

      print "Updating host and guest associations..." if option_verbose?
      @host_guests.each do |host_id, guest_ids|
        @k_system_api.update({
                               'id' => host_id,
                               'guest_ids' => guest_ids
                             })
      end
      puts "done" if option_verbose?
    end

    def create_systems_from_csv(line)
      if !@existing[line[ORGANIZATION]]
        @existing[line[ORGANIZATION]] = {}
        @k_system_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999})[0]['results'].each do |system|
          @existing[line[ORGANIZATION]][system['name']] = system['uuid'] if system
        end
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)

        # TODO w/ @daviddavis p-r
        #subscriptions(line).each do |subscription|
        #  katello_subscription(line[ORGANIZATION], :name => subscription[:number])
        #end

        if !@existing[line[ORGANIZATION]].include? name
          print "Creating system '#{name}'..." if option_verbose?
          system_id = @k_system_api.create({
                                 'name' => name,
                                 'organization_id' => line[ORGANIZATION],
                                 'environment_id' => katello_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                                 'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                                 'facts' => facts(line),
                                 'installed_products' => products(line),
                                 'type' => 'system'
                               })[0]['uuid']
          @existing[line[ORGANIZATION]][name] = system_id
        else
          print "Updating system '#{name}'..." if option_verbose?
          puts line
          system_id = @k_system_api.update({
                                 'id' => @existing[line[ORGANIZATION]][name],
                                 'name' => name,
                                 'environment_id' => katello_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                                 'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                                 'facts' => facts(line),
                                 'installed_products' => products(line)
                               })[0]['uuid']
        end

        if line[VIRTUAL] == 'Yes' && line[HOST]
          raise "Host system '#{line[HOST]}' not found" if !@existing[line[ORGANIZATION]][line[HOST]]
          @host_guests[@existing[line[ORGANIZATION]][line[HOST]]] ||= []
          @host_guests[@existing[line[ORGANIZATION]][line[HOST]]] << system_id
        end

        set_system_groups(system_id, line)

        puts "done" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end

    private

    def facts(line)
      facts = {}
      facts['cpu.core(s)_per_socket'] = line[CORES]
      facts['cpu.cpu_socket(s)'] = line[SOCKETS]
      facts['memory.memtotal'] = line[RAM]
      facts['uname.machine'] = line[ARCHITECTURE]
      if line[OPERATINGSYSTEM].index(' ')
        (facts['distribution.name'], facts['distribution.version']) = line[OPERATINGSYSTEM].split(' ')
      else
        (facts['distribution.name'], facts['distribution.version']) = ['RHEL', line[OPERATINGSYSTEM]]
      end
      facts['virt.is_guest'] = line[VIRTUAL] == 'Yes' ? true : false
      facts
    end

    def set_system_groups(system_id, line)
      CSV.parse_line(line[SYSTEMGROUPS]).each do |systemgroup_name|
        @k_systemgroup_api.add_systems({
                                         'id' => katello_systemgroup(line[ORGANIZATION], :name => systemgroup_name),
                                         'system_ids' => [system_id]
                                       })
      end
    end

    def products(line)
      products = CSV.parse_line(line[PRODUCTS]).collect do |product_details|
        product = {}
        # TODO: these get passed straight through to candlepin; probably would be better to process in server
        #       to allow underscore product_id here
        (product['productId'], product['productName']) = product_details.split('|')
        product
      end
      products
    end

    def subscriptions(line)
      subscriptions = CSV.parse_line(line[SUBSCRIPTIONS]).collect do |subscription_details|
        subscription = {}
        (subscription[:number], subscription[:name]) = subscription_details.split('|')
        subscription
      end
      subscriptions
    end

  end

  HammerCLI::MainCommand.subcommand("csv:puppetreports", "import/export puppet reports", HammerCLICsv::PuppetReportsCommand)
end
