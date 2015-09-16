module HammerCLICsv
  class CsvCommand
    class ContentHostsCommand < BaseCommand
      include ::HammerCLIForemanTasks::Helper

      command_name 'content-hosts'
      desc         'import or export content hosts'

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
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
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
        guests_hypervisor = {}
        host_ids = []

        @headpin.get(:organizations).each do |organization|
          next if option_organization && organization['name'] != option_organization
          host_ids = @headpin.get("organizations/#{organization['label']}/systems").collect do |host|
            host['guests'].each { |guest| guests_hypervisor[guest['uuid']] = host['name'] }
            host['uuid']
          end
        end

        host_ids.each do |host_id|
          host = @headpin.get("systems/#{host_id}")
          host_subscriptions = @headpin.get("systems/#{host_id}/subscriptions")['entitlements']

          name = host['name']
          count = 1
          organization_name = host['owner']['displayName']
          environment = host['environment']['name']
          contentview = host['content_view']['name']
          hostcollections = nil
          virtual = host['facts']['virt.is_guest'] == 'true' ? 'Yes' : 'No'
          hypervisor = guests_hypervisor[host['uuid']]
          if host['facts']['distribution.name']
            operatingsystem = "#{host['facts']['distribution.name']} "
            operatingsystem += host['facts']['distribution.version'] if host['facts']['distribution.version']
            operatingsystem.strip!
          end
          architecture = host['facts']['uname.machine']
          sockets = host['facts']['cpu.cpu_socket(s)']
          ram = host['facts']['memory.memtotal']
          cores = host['facts']['cpu.core(s)_per_socket'] || 1
          sla = host['serviceLevel']

          products = CSV.generate do |column|
            column << host['installedProducts'].collect do |product|
              "#{product['productId']}|#{product['productName']}"
            end
          end
          products.delete!("\n")

          subscriptions = CSV.generate do |column|
            column << host_subscriptions.collect do |subscription|
              "#{subscription['quantity']}|#{subscription['productId']}|#{subscription['poolName']}"
            end
          end
          subscriptions.delete!("\n")

          csv << [name, count, organization_name, environment, contentview, hostcollections, virtual, hypervisor,
                  operatingsystem, architecture, sockets, ram, cores, sla, products, subscriptions]
        end
      end

      def export_foretello(csv)
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          @api.resource(:systems).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => organization['name'])
          })['results'].each do |host|
            host = @api.resource(:systems).call(:show, {
                'id' => host['uuid'],
                'fields' => 'full'
            })

            name = host['name']
            count = 1
            organization_name = organization['name']
            environment = host['environment']['label']
            contentview = host['content_view']['name']
            hostcollections = CSV.generate do |column|
              column << host['hostCollections'].collect do |hostcollection|
                hostcollection['name']
              end
            end
            hostcollections.delete!("\n")
            virtual = host['facts']['virt.is_guest'] == 'true' ? 'Yes' : 'No'
            hypervisor_host = host['virtual_host'].nil? ? nil : host['virtual_host']['name']
            operatingsystem = "#{host['facts']['distribution.name']} " if host['facts']['distribution.name']
            operatingsystem += host['facts']['distribution.version'] if host['facts']['distribution.version']
            architecture = host['facts']['uname.machine']
            sockets = host['facts']['cpu.cpu_socket(s)']
            ram = host['facts']['memory.memtotal']
            cores = host['facts']['cpu.core(s)_per_socket'] || 1
            sla = ''
            products = CSV.generate do |column|
              column << host['installedProducts'].collect do |product|
                "#{product['productId']}|#{product['productName']}"
              end
            end
            products.delete!("\n")
            subscriptions = CSV.generate do |column|
              column << @api.resource(:subscriptions).call(:index, {
                  'organization_id' => organization['id'],
                  'system_id' => host['uuid']
              })['results'].collect do |subscription|
                "#{subscription['consumed']}|#{subscription['product_id']}|#{subscription['product_name']}"
              end
            end
            subscriptions.delete!("\n")
            csv << [name, count, organization_name, environment, contentview, hostcollections, virtual, hypervisor_host,
                    operatingsystem, architecture, sockets, ram, cores, sla, products, subscriptions]
          end
        end
      end

      def import
        remote = @server_status['plugins'].detect { |plugin| plugin['name'] == 'foreman_csv' }
        if remote.nil?
          import_locally
        else
          import_remotely
        end
      end

      def import_remotely
        params = {'content' => ::File.new(::File.expand_path(option_file), 'rb')}
        headers = {:content_type => 'multipart/form-data', :multipart => true}
        task_progress(@api.resource(:csv).call(:import_content_hosts, params, headers))
      end

      def import_locally
        @existing = {}
        @hypervisor_guests = {}

        thread_import do |line|
          create_content_hosts_from_csv(line)
        end

        if !@hypervisor_guests.empty?
          print(_('Updating hypervisor and guest associations...')) if option_verbose?
          @hypervisor_guests.each do |host_id, guest_ids|
            @api.resource(:systems).call(:update, {
                'id' => host_id,
                'guest_ids' => guest_ids
            })
          end
          puts _('done') if option_verbose?
        end
      end

      def create_content_hosts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

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
            })['results'].each do |host|
              @existing[line[ORGANIZATION]][host['name']] = host['uuid'] if host
            end
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          if !@existing[line[ORGANIZATION]].include? name
            print(_("Creating content host '%{name}'...") % {:name => name}) if option_verbose?
            host_id = @api.resource(:systems).call(:create, {
                'name' => name,
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                'facts' => facts(name, line),
                'installed_products' => products(line),
                'service_level' => line[SLA],
                'type' => 'system'
            })['uuid']
            @existing[line[ORGANIZATION]][name] = host_id
          else
            print(_("Updating content host '%{name}'...") % {:name => name}) if option_verbose?
            host_id = @api.resource(:systems).call(:update, {
                'id' => @existing[line[ORGANIZATION]][name],
                'system' => {
                    'name' => name,
                    'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                    'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                    'facts' => facts(name, line),
                    'installed_products' => products(line)
                },
                'facts' => facts(name, line),
                'installed_products' => products(line),  # TODO: http://projects.theforeman.org/issues/9191,
                'service_level' => line[SLA]
            })['uuid']
          end

          if line[VIRTUAL] == 'Yes' && line[HOST]
            raise "Content host '#{line[HOST]}' not found" if !@existing[line[ORGANIZATION]][line[HOST]]
            @hypervisor_guests[@existing[line[ORGANIZATION]][line[HOST]]] ||= []
            @hypervisor_guests[@existing[line[ORGANIZATION]][line[HOST]]] << "#{line[ORGANIZATION]}/#{name}"
          end

          update_host_collections(host_id, line)
          update_subscriptions(host_id, line)

          puts _('done') if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def facts(name, line)
        facts = {}
        facts['system.certificate_version'] = '3.2'  # Required for auto-attach to work
        facts['network.hostname'] = name
        facts['cpu.core(s)_per_socket'] = line[CORES]
        facts['cpu.cpu_socket(s)'] = line[SOCKETS]
        facts['memory.memtotal'] = line[RAM]
        facts['uname.machine'] = line[ARCHITECTURE]
        (facts['distribution.name'], facts['distribution.version']) = os_name_version(line[OPERATINGSYSTEM])
        facts['virt.is_guest'] = line[VIRTUAL] == 'Yes' ? true : false
        facts['virt.uuid'] = "#{line[ORGANIZATION]}/#{name}" if facts['virt.is_guest']
        facts['cpu.cpu(s)'] = 1
        facts
      end

      def update_host_collections(host_id, line)
        return nil if !line[HOSTCOLLECTIONS]
        CSV.parse_line(line[HOSTCOLLECTIONS]).each do |hostcollection_name|
          @api.resource(:host_collections).call(:add_systems, {
              'id' => katello_hostcollection(line[ORGANIZATION], :name => hostcollection_name),
              'system_ids' => [host_id]
          })
        end
      end

      def os_name_version(operatingsystem)
        if operatingsystem.nil?
          name = nil
          version = nil
        elsif operatingsystem.index(' ')
          (name, version) = operatingsystem.split(' ')
        else
          (name, version) = ['RHEL', operatingsystem]
        end
        [name, version]
      end

      def products(line)
        return nil if !line[PRODUCTS]
        products = CSV.parse_line(line[PRODUCTS]).collect do |product_details|
          product = {}
          # TODO: these get passed straight through to candlepin; probably would be better to process in server
          #       to allow underscore product_id here
          (product['productId'], product['productName']) = product_details.split('|')
          product['arch'] = line[ARCHITECTURE]
          product['version'] = os_name_version(line[OPERATINGSYSTEM])[1]
          product
        end
        products
      end

      def update_subscriptions(host_id, line)
        existing_subscriptions = @api.resource(:subscriptions).call(:index, {
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'per_page' => 999999,
            'system_id' => host_id
        })['results']
        if existing_subscriptions.length > 0
          @api.resource(:subscriptions).call(:destroy, {
            'system_id' => host_id,
            'id' => existing_subscriptions[0]['id']
          })
        end

        return if line[SUBSCRIPTIONS].nil? || line[SUBSCRIPTIONS].empty?

        subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |details|
          (amount, sku, name) = details.split('|')
          {
            :id => katello_subscription(line[ORGANIZATION], :name => name),
            :quantity => (amount.nil? || amount.empty? || amount == 'Automatic') ? 0 : amount.to_i
          }
        end

        @api.resource(:subscriptions).call(:create, {
            'system_id' => host_id,
            'subscriptions' => subscriptions
        })
      end
    end
  end
end
