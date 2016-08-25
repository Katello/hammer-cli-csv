#require 'hammer_cli_csv/utils/subscription_utils'

module HammerCLICsv
  class CsvCommand
    class ContentHostsCommand < BaseCommand
      include ::HammerCLIForemanTasks::Helper
      include ::HammerCLICsv::Utils::Subscriptions

      command_name 'content-hosts'
      desc         'import or export content hosts'

      def self.supported?
        true
      end

      option %w(--itemized-subscriptions), :flag, _('Export one subscription per row, only process update subscriptions on import')

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

      def export(csv)
        if option_itemized_subscriptions?
          export_itemized_subscriptions csv
        else
          export_all csv
        end
      end

      def export_itemized_subscriptions(csv)
        csv << shared_headers + [Utils::Subscriptions::SUBS_NAME, Utils::Subscriptions::SUBS_TYPE,
                                 Utils::Subscriptions::SUBS_QUANTITY, Utils::Subscriptions::SUBS_SKU,
                                 Utils::Subscriptions::SUBS_CONTRACT, Utils::Subscriptions::SUBS_ACCOUNT,
                                 Utils::Subscriptions::SUBS_START, Utils::Subscriptions::SUBS_END]
        iterate_hosts(csv) do |host|
          export_line = shared_columns(host)
          if host['subscription_facet_attributes']
            subscriptions = @api.resource(:host_subscriptions).call(:index, {
                'organization_id' => host['organization_id'],
                'host_id' => host['id']
            })['results']
            if subscriptions.empty?
              csv << export_line + [nil, nil, nil, nil, nil, nil]
            else
              subscriptions.each do |subscription|
                subscription_type = subscription['product_id'].to_i == 0 ? 'Red Hat' : 'Custom'
                subscription_type += ' Guest' if subscription['type'] == 'STACK_DERIVED'
                subscription_type += ' Temporary' if subscription['type'] == 'UNMAPPED_GUEST'
                csv << export_line + [subscription['product_name'], subscription_type,
                                      subscription['quantity_consumed'], subscription['product_id'],
                                      subscription['contract_number'], subscription['account_number'],
                                      DateTime.parse(subscription['start_date']).strftime('%m/%d/%Y'),
                                      DateTime.parse(subscription['end_date']).strftime('%m/%d/%Y')]
              end
            end
          else
            csv << export_line + [nil, nil, nil, nil, nil, nil]
          end
        end
      end

      def export_all(csv)
        csv << shared_headers + [Utils::Subscriptions::SUBSCRIPTIONS]
        iterate_hosts(csv) do |host|
          if host['subscription_facet_attributes']
            subscriptions = CSV.generate do |column|
              column << @api.resource(:host_subscriptions).call(:index, {
                  'organization_id' => host['organization_id'],
                  'host_id' => host['id']
              })['results'].collect do |subscription|
                "#{subscription['quantity_consumed']}"\
                "|#{subscription['product_id']}"\
                "|#{subscription['product_name']}"\
                "|#{subscription['contract_number']}|#{subscription['account_number']}"
              end
            end
            subscriptions.delete!("\n")
          else
            subscriptions = nil
          end

          csv << shared_columns(host) + [subscriptions]
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
        @all_subscriptions = {}

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
                  'autoheal' => false,
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

          if option_itemized_subscriptions?
            update_itemized_subscriptions(name, line)
          else
            update_or_create(name, line)
          end
        end
      end

      private

      def update_itemized_subscriptions(name, line)
        raise _("Content host '%{name}' must already exist with --itemized-subscriptions") % {:name => name} unless @existing.include? name

        print(_("Updating subscriptions for content host '%{name}'...") % {:name => name}) if option_verbose?
        host = @api.resource(:hosts).call(:show, {:id => @existing[name]})
        update_subscriptions(host, line, false)
        puts _('done') if option_verbose?
      end

      def update_or_create(name, line)
        if !@existing.include? name
          print(_("Creating content host '%{name}'...") % {:name => name}) if option_verbose?
          params = {
            'name' => name,
            'facts' => facts(name, line),
            'lifecycle_environment_id' => lifecycle_environment(line[ORGANIZATION], :name => line[ENVIRONMENT]),
            'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW])
          }
          params['installed_products'] = products(line) if line[PRODUCTS]
          params['service_level'] = line[SLA] if line[SLA]
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
        update_subscriptions(host, line, true)

        puts _('done') if option_verbose?
      end

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
        # TODO: http://projects.theforeman.org/issues/16234
        # return nil if line[HOSTCOLLECTIONS].nil? || line[HOSTCOLLECTIONS].empty?
        # CSV.parse_line(line[HOSTCOLLECTIONS]).each do |hostcollection_name|
        #   @api.resource(:host_collections).call(:add_hosts, {
        #       'id' => katello_hostcollection(line[ORGANIZATION], :name => hostcollection_name),
        #       'host_ids' => [host['id']]
        #   })
        # end
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

      def update_subscriptions(host, line, remove_existing)
        existing_subscriptions = @api.resource(:host_subscriptions).call(:index, {
            'host_id' => host['id']
        })['results']
        if remove_existing && existing_subscriptions.length != 0
          existing_subscriptions.map! do |existing_subscription|
            {:id => existing_subscription['id'], :quantity => existing_subscription['quantity_consumed']}
          end
          @api.resource(:host_subscriptions).call(:remove_subscriptions, {
            'host_id' => host['id'],
            'subscriptions' => existing_subscriptions
          })
          existing_subscriptions = []
        end

        if line[Utils::Subscriptions::SUBS_NAME].nil? && line[Utils::Subscriptions::SUBS_SKU].nil?
          all_in_one_subscription(host, existing_subscriptions, line)
        else
          single_subscription(host, existing_subscriptions, line)
        end
      end

      def single_subscription(host, existing_subscriptions, line)
        already_attached = false
        if line[Utils::Subscriptions::SUBS_SKU]
          already_attached = existing_subscriptions.detect do |subscription|
            line[Utils::Subscriptions::SUBS_SKU] == subscription['product_id']
          end
        elsif line[Utils::Subscriptions::SUBS_NAME]
          already_attached = existing_subscriptions.detect do |subscription|
            line[Utils::Subscriptions::SUBS_NAME] == subscription['name']
          end
        end
        if already_attached
          print _(" '%{name}' already attached...") % {:name => already_attached['name']}
          return
        end

        available_subscriptions = @api.resource(:subscriptions).call(:index, {
          'organization_id' => host['organization_id'],
          'host_id' => host['id'],
          'available_for' => 'host',
          'match_host' => true
        })['results']

        matches = matches_by_sku_and_name([], line, available_subscriptions)
        matches = matches_by_type(matches, line)
        matches = matches_by_account(matches, line)
        matches = matches_by_contract(matches, line)
        matches = matches_by_quantity(matches, line)

        raise _("No matching subscriptions") if matches.empty?

        match = matches[0]
        print _(" attaching '%{name}'...") % {:name => match['name']} if option_verbose?

        @api.resource(:host_subscriptions).call(:add_subscriptions, {
            'host_id' => host['id'],
            'subscriptions' => existing_subscriptions + [match]
        })
      end

      def all_in_one_subscription(host, existing_subscriptions, line)
        return if line[SUBSCRIPTIONS].nil? || line[SUBSCRIPTIONS].empty?

        subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |details|
          (amount, sku, name, contract, account) = split_subscription_details(details)
          {
            :id => get_subscription(line[ORGANIZATION], :name => name, :contract => contract,
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

      def iterate_hosts(csv)
        hypervisors = []
        hosts = []
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
            if host['subscription_facet_attributes']['virtual_guests'].empty?
              hosts.push(host)
            else
              hypervisors.push(host)
            end
          end
        end
        hypervisors.each do |host|
          yield host
        end
        hosts.each do |host|
          yield host
        end
      end

      def shared_headers
        [NAME, ORGANIZATION, ENVIRONMENT, CONTENTVIEW, HOSTCOLLECTIONS, VIRTUAL, HOST,
         OPERATINGSYSTEM, ARCHITECTURE, SOCKETS, RAM, CORES, SLA, PRODUCTS]
      end

      def shared_columns(host)
        name = host['name']
        organization_name = host['organization_name']
        if host['content_facet_attributes']
          environment = host['content_facet_attributes']['lifecycle_environment']['name']
          contentview = host['content_facet_attributes']['content_view']['name']
          hostcollections = export_column(host['content_facet_attributes'], 'host_collections', 'name')
        else
          environment = nil
          contentview = nil
          hostcollections = nil
        end
        if host['subscription_facet_attributes']
          hypervisor_host = host['subscription_facet_attributes']['virtual_host'].nil? ? nil : host['subscription_facet_attributes']['virtual_host']['name']
          products = export_column(host['subscription_facet_attributes'], 'installed_products') do |product|
            "#{product['productId']}|#{product['productName']}"
          end
        else
          hypervisor_host = nil
          products = nil
        end
        virtual = host['facts']['virt::is_guest'] == 'true' ? 'Yes' : 'No'
        operatingsystem = host['facts']['distribution::name'] if host['facts']['distribution::name']
        operatingsystem += " #{host['facts']['distribution::version']}" if host['facts']['distribution::version']
        architecture = host['facts']['uname::machine']
        sockets = host['facts']['cpu::cpu_socket(s)']
        ram = host['facts']['memory::memtotal']
        cores = host['facts']['cpu::core(s)_per_socket'] || 1
        sla = ''

        [name, organization_name, environment, contentview, hostcollections, virtual, hypervisor_host,
         operatingsystem, architecture, sockets, ram, cores, sla, products]
      end

    end
  end
end
