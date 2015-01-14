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
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class CsvCommand
    class ContentHostsCommand < BaseCommand
      command_name 'content-hosts'
      desc         'import or export content hosts'

      option %w(--sam), :flag, 'export from SAM-1.3 or SAM-1.4'

      ORGANIZATION = 'Organization'
      ENVIRONMENT = 'Environment'
      CONTENTVIEW = 'Content View'
      HOSTCOLLECTIONS = 'Host Collections'
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
          csv << [NAME, COUNT, ORGANIZATION, ENVIRONMENT, CONTENTVIEW, HOSTCOLLECTIONS, VIRTUAL, HOST,
                  OPERATINGSYSTEM, ARCHITECTURE, SOCKETS, RAM, CORES, SLA, PRODUCTS, SUBSCRIPTIONS]
          if @server_status['release'] == 'Headpin'
            export_sam csv
          else
            export_foretello csv
          end
        end
      end

      def export_sam(csv)
        guests_host = {}
        system_ids = []

        @headpin.get(:organizations).each do |organization|
          #url = "#{server}/api/systems?organization_id=satellite-1"
          system_ids = @headpin.get("organizations/#{organization['label']}/systems").collect do |system|
            system['guests'].each { |guest| guests_host[guest['uuid']] = system['name'] }
            system['uuid']
          end
        end

        system_ids.each do |system_id|
          system = @headpin.get("systems/#{system_id}")
          system_subscriptions = @headpin.get("systems/#{system_id}/subscriptions")['entitlements']

          name = system['name']
          count = 1
          organization_name = system['owner']['displayName']
          environment = system['environment']['name']
          contentview = system['content_view']['name']
          hostcollections = nil
          virtual = system['facts']['virt.is_guest'] == 'true' ? 'Yes' : 'No'
          host = guests_host[system['uuid']]
          if system['facts']['distribution.name']
            operatingsystem = "#{system['facts']['distribution.name']} "
            operatingsystem += system['facts']['distribution.version'] if system['facts']['distribution.version']
            operatingsystem.strip!
          end
          architecture = system['facts']['uname.machine']
          sockets = system['facts']['cpu.cpu_socket(s)']
          ram = system['facts']['memory.memtotal']
          cores = system['facts']['cpu.core(s)_per_socket'] || 1
          sla = system['serviceLevel']

          products = CSV.generate do |column|
            column << system['installedProducts'].collect do |product|
              "#{product['productId']}|#{product['productName']}"
            end
          end
          products.delete!("\n")

          subscriptions = CSV.generate do |column|
            column << system_subscriptions.collect do |subscription|
              "#{subscription['quantity']}|#{subscription['productId']}|#{subscription['poolName']}"
            end
          end
          subscriptions.delete!("\n")

          csv << [name, count, organization_name, environment, contentview, hostcollections, virtual, host,
                  operatingsystem, architecture, sockets, ram, cores, sla, products, subscriptions]
        end
      end

      def export_foretello(csv)
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          @api.resource(:systems).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => organization['name'])
          })['results'].each do |system|
            system = @api.resource(:systems).call(:show, {
                'id' => system['uuid'],
                'fields' => 'full'
            })

            name = system['name']
            count = 1
            organization_name = organization['name']
            environment = system['environment']['label']
            contentview = system['content_view']['name']
            hostcollections = CSV.generate do |column|
              column << system['hostCollections'].collect do |hostcollection|
                hostcollection['name']
              end
            end
            hostcollections.delete!("\n")
            virtual = system['facts']['virt.is_guest'] == 'true' ? 'Yes' : 'No'
            host = system['virtual_host'].nil? ? nil : system['virtual_host']['name']
            operatingsystem = "#{system['facts']['distribution.name']} " if system['facts']['distribution.name']
            operatingsystem += system['facts']['distribution.version'] if system['facts']['distribution.version']
            architecture = system['facts']['uname.machine']
            sockets = system['facts']['cpu.cpu_socket(s)']
            ram = system['facts']['memory.memtotal']
            cores = system['facts']['cpu.core(s)_per_socket'] || 1
            sla = ''
            products = CSV.generate do |column|
              column << system['installedProducts'].collect do |product|
                "#{product['productId']}|#{product['productName']}"
              end
            end
            products.delete!("\n")
            subscriptions = CSV.generate do |column|
              column << @api.resource(:subscriptions).call(:index, {
                  'organization_id' => organization['id'],
                  'system_id' => system['uuid']
              })['results'].collect do |subscription|
                "#{subscription['consumed']}|#{subscription['product_id']}|#{subscription['product_name']}"
              end
            end
            subscriptions.delete!("\n")
            csv << [name, count, organization_name, environment, contentview, hostcollections, virtual, host,
                    operatingsystem, architecture, sockets, ram, cores, sla, products, subscriptions]
          end
        end
      end

      def import
        @existing = {}
        @host_guests = {}

        thread_import do |line|
          create_systems_from_csv(line)
        end

        print 'Updating host and guest associations...' if option_verbose?
        @host_guests.each do |host_id, guest_ids|
          @api.resource(:systems).call(:update, {
              'id' => host_id,
              'guest_ids' => guest_ids
          })
        end
        puts 'done' if option_verbose?
      end

      def create_systems_from_csv(line)
        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          # Fetching all content hosts is too slow and times out due to the complexity of the data
          # rendered in the json.
          # http://projects.theforeman.org/issues/6307
          total = @api.resource(:systems).call(:index, {
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'per_page' => 1
          })['total'].to_i
          (total / 20 + 2).to_i.times do |page|
            @api.resource(:systems).call(:index, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'page' => page,
                'per_page' => 20
            })['results'].each do |system|
              @existing[line[ORGANIZATION]][system['name']] = system['uuid'] if system
            end
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          # TODO: w/ @daviddavis p-r
          #subscriptions(line).each do |subscription|
          #  katello_subscription(line[ORGANIZATION], :name => subscription[:number])
          #end

          if !@existing[line[ORGANIZATION]].include? name
            print "Creating system '#{name}'..." if option_verbose?
            system_id = @api.resource(:systems).call(:create, {
                'name' => name,
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                'facts' => facts(name, line),
                'installed_products' => products(line),
                'type' => 'system'
            })['uuid']
            @existing[line[ORGANIZATION]][name] = system_id
          else
            print "Updating system '#{name}'..." if option_verbose?
            system_id = @api.resource(:systems).call(:update, {
                'id' => @existing[line[ORGANIZATION]][name],
                'system' => {
                    'name' => name,
                    'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                    'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                    'facts' => facts(name, line),
                    'installed_products' => products(line)
                }
            })['uuid']
          end

          if line[VIRTUAL] == 'Yes' && line[HOST]
            raise "Host system '#{line[HOST]}' not found" if !@existing[line[ORGANIZATION]][line[HOST]]
            @host_guests[@existing[line[ORGANIZATION]][line[HOST]]] ||= []
            @host_guests[@existing[line[ORGANIZATION]][line[HOST]]] << "#{line[ORGANIZATION]}/#{name}"
          end

          set_host_collections(system_id, line)

          puts 'done' if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def facts(name, line)
        facts = {}
        facts['network.hostname'] = name
        facts['cpu.core(s)_per_socket'] = line[CORES]
        facts['cpu.cpu_socket(s)'] = line[SOCKETS]
        facts['memory.memtotal'] = line[RAM]
        facts['uname.machine'] = line[ARCHITECTURE]
        if line[OPERATINGSYSTEM].nil?
          facts['distribution.name'] = nil
          facts['distribution.version'] = nil
        elsif line[OPERATINGSYSTEM].index(' ')
          (facts['distribution.name'], facts['distribution.version']) = line[OPERATINGSYSTEM].split(' ')
        else
          (facts['distribution.name'], facts['distribution.version']) = ['RHEL', line[OPERATINGSYSTEM]]
        end
        facts['virt.is_guest'] = line[VIRTUAL] == 'Yes' ? true : false
        facts['virt.uuid'] = "#{line[ORGANIZATION]}/#{name}" if facts['virt.is_guest']
        facts
      end

      def set_host_collections(system_id, line)
        return nil if !line[HOSTCOLLECTIONS]
        CSV.parse_line(line[HOSTCOLLECTIONS]).each do |hostcollection_name|
          @api.resource(:host_collections).call(:add_systems, {
              'id' => katello_hostcollection(line[ORGANIZATION], :name => hostcollection_name),
              'system_ids' => [system_id]
          })
        end
      end

      def products(line)
        return nil if !line[PRODUCTS]
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
        return nil if !line[SUBSCRIPTIONS]
        subscriptions = CSV.parse_line(line[SUBSCRIPTIONS]).collect do |subscription_details|
          subscription = {}
          (subscription[:quantity], subscription[:number], subscription[:name]) = subscription_details.split('|')
          subscription
        end
        subscriptions
      end
    end
  end
end
