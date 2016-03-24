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
          csv << [NAME, ORGANIZATION, ENVIRONMENT, CONTENTVIEW, HOSTCOLLECTIONS, VIRTUAL, HOST,
                  OPERATINGSYSTEM, ARCHITECTURE, SOCKETS, RAM, CORES, SLA, PRODUCTS, SUBSCRIPTIONS]
          export_katello csv
        end
      end

      def export_katello(csv)
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          @api.resource(:hosts).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => organization['name'])
          })['results'].each do |host|
            host = @api.resource(:hosts).call(:show, {
                'id' => host['id']
            })
            host['facts'] ||= {}

            name = host['name']
            organization_name = organization['name']
            if host['content_facet_attributes']
              environment = host['content_facet_attributes']['lifecycle_environment']['name']
              contentview = host['content_facet_attributes']['content_view']['name']
              hostcollections = export_column(host['content_facet_attributes'], 'host_collections', 'name')
            else
              environment = nil
              contentview = nil
              hostcollections = nil
            end
            virtual = host['facts']['virt::is_guest'] == 'true' ? 'Yes' : 'No'
            hypervisor_host = host['subscription_facet_attributes']['virtual_host'].nil? ? nil : host['subscription_facet_attributes']['virtual_host']['name']
            operatingsystem = host['facts']['distribution::name'] if host['facts']['distribution::name']
            operatingsystem += " #{host['facts']['distribution::version']}" if host['facts']['distribution::version']
            architecture = host['facts']['uname::machine']
            sockets = host['facts']['cpu::cpu_socket(s)']
            ram = host['facts']['memory::memtotal']
            cores = host['facts']['cpu::core(s)_per_socket'] || 1
            sla = ''
            products = export_column(host['subscription_facet_attributes'], 'installed_products', 'productName')
            subscriptions = CSV.generate do |column|
              column << @api.resource(:host_subscriptions).call(:index, {
                  'organization_id' => organization['id'],
                  'host_id' => host['id']
              })['results'].collect do |subscription|
                "#{subscription['quantity_consumed']}"\
                "|#{subscription['product_id']}"\
                "|#{subscription['product_name']}"\
                "|#{subscription['contract_number']}|#{subscription['account_number']}"
              end
            end
            subscriptions.delete!("\n")
            csv << [name, organization_name, environment, contentview, hostcollections, virtual, hypervisor_host,
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
          create_from_csv(line)
        end

        if !@hypervisor_guests.empty?
          print(_('Updating hypervisor and guest associations...')) if option_verbose?
          @hypervisor_guests.each do |host_id, guest_ids|
            @api.resource(:hosts).call(:update, {
              'id' => host_id,
              'host' => {
                'subscription_facet_attributes' => {
                  'hypervisor_guest_uuids' => guest_ids
                }
              }
            })
          end
          puts _('done') if option_verbose?
        end
      end

      def create_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        update_existing(line)

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)

          if !@existing.include? name
            print(_("Creating content host '%{name}'...") % {:name => name}) if option_verbose?
            params = {
              'name' => name,
              'facts' => facts(name, line),
              'lifecycle_environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
              'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
              'installed_products' => products(line),
              'service_level' => line[SLA]
            }
            host = @api.resource(:host_subscriptions).call(:create, params)
            @existing[name] = host['id']
          else
            print(_("Updating content host '%{name}'...") % {:name => name}) if option_verbose?
            params = {
              'id' => @existing[name],
              'host' => {
                'content_facet_attributes' => {
                  'lifecycle_environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
                  'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW])
                },
                'subscription_facet_attributes' => {
                  'facts' => facts(name, line),
                  'installed_products' => products(line),
                  'service_level' => line[SLA]
                }
              }
            }
            host = @api.resource(:hosts).call(:update, params)
          end

          if line[VIRTUAL] == 'Yes' && line[HOST]
            raise "Content host '#{line[HOST]}' not found" if !@existing[line[HOST]]
            @hypervisor_guests[@existing[line[HOST]]] ||= []
            @hypervisor_guests[@existing[line[HOST]]] << "#{line[ORGANIZATION]}/#{name}"
          end

          update_host_collections(host, line)
          update_subscriptions(host, line)

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

      def update_host_collections(host, line)
        return nil if !line[HOSTCOLLECTIONS]
        CSV.parse_line(line[HOSTCOLLECTIONS]).each do |hostcollection_name|
          @api.resource(:host_collections).call(:add_hosts, {
              'id' => katello_hostcollection(line[ORGANIZATION], :name => hostcollection_name),
              'host_ids' => [host['id']]
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
        CSV.parse_line(line[PRODUCTS]).collect do |product_details|
          product = {}
          (product['product_id'], product['product_name']) = product_details.split('|')
          product['arch'] = line[ARCHITECTURE]
          product['version'] = os_name_version(line[OPERATINGSYSTEM])[1]
          product
        end
      end

      def update_subscriptions(host, line)
        existing_subscriptions = @api.resource(:host_subscriptions).call(:index, {
            'host_id' => host['id']
        })['results']
        if existing_subscriptions.length != 0
          @api.resource(:host_subscriptions).call(:remove_subscriptions, {
            'host_id' => host['id'],
            'subscriptions' => existing_subscriptions
          })
        end

        return if line[SUBSCRIPTIONS].nil? || line[SUBSCRIPTIONS].empty?

        subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |details|
          (amount, sku, name, contract, account) = details.split('|')
          {
            :id => katello_subscription(line[ORGANIZATION], :name => name, :contract => contract,
                                                            :account => account),
            :quantity => (amount.nil? || amount.empty? || amount == 'Automatic') ? 0 : amount.to_i
          }
        end

        @api.resource(:host_subscriptions).call(:add_subscriptions, {
            'host_id' => host['id'],
            'subscriptions' => subscriptions
        })
      end

      def update_existing(line)
        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = true
          # Fetching all content hosts can be too slow and times so page
          # http://projects.theforeman.org/issues/6307
          total = @api.resource(:hosts).call(:index, {
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'per_page' => 1
          })['total'].to_i
          (total / 20 + 1).to_i.times do |page|
            @api.resource(:hosts).call(:index, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'page' => page + 1,
                'per_page' => 20
            })['results'].each do |host|
              if host['subscription_facet_attributes']
                @existing[host['name']] = host['id']
              end
            end
          end
        end
      end
    end
  end
end
