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

require 'openssl'
require 'date'

module HammerCLICsv
  class CsvCommand
    class SpliceCommand < BaseCommand
      command_name 'splice'
      desc         'import Satellite-5 splice data'

      option %w(--organization), 'ORGANIZATION', 'Only process organization matching this name'
      option %w(--dir), 'DIR',
          'Directory of Splice exported CSV files (default pwd)'
      option %w(--mapping-dir), 'DIR',
          'Directory of Splice product mapping files (default /usr/share/rhsm/product/RHEL-6)'

      UUID = 'server_id'
      ORGANIZATION = 'organization'
      ORGANIZATION_ID = 'org_id'
      NAME = 'name'
      HOSTNAME = 'hostname'
      IP_ADDRESS = 'ip_address'
      IPV6_ADDRESS = 'ipv6_address'
      REGISTERED_BY = 'registered_by'
      REGISTRATION_TIME = 'registration_time'
      LAST_CHECKIN_TIME = 'last_checkin_time'
      PRODUCTS = 'software_channel'
      ENTITLEMENTS = 'entitlements'
      HOSTCOLLECTIONS = 'system_group'
      VIRTUAL_HOST = 'virtual_host'
      ARCHITECTURE = 'architecture'
      HARDWARE = 'hardware'
      MEMORY = 'memory'
      SOCKETS = 'sockets'
      IS_VIRTUALIZED = 'is_virtualized'

      def import
        @existing = {}
        load_product_mapping
        preload_host_guests

        filename = option_dir + '/splice-export'
        thread_import(false, filename, NAME) do |line|
          create_content_hosts_from_csv(line) unless line[UUID][0] == '#'
        end

        update_host_guests
        delete_unfound_hosts(@existing)
      end

      def create_content_hosts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        if !@existing[line[ORGANIZATION]]
          create_organization(line)
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

        name = "#{line[NAME]}-#{line[UUID]}"
        #checkin_time = Time.parse(line[LAST_CHECKIN_TIME]).strftime("%a, %d %b %Y %H:%M:%S %z")
        checkin_time = if line[LAST_CHECKIN_TIME].casecmp('now').zero?
                         DateTime.now.strftime("%a, %d %b %Y %H:%M:%S %z")
                       else
                         DateTime.parse(line[LAST_CHECKIN_TIME]).strftime("%a, %d %b %Y %H:%M:%S %z")
                       end

        if !@existing[line[ORGANIZATION]].include? name
          print(_("Creating content host '%{name}'...") % {:name => name}) if option_verbose?
          host_id = @api.resource(:systems).call(:create, {
              'name' => name,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => 'Library'),
              'content_view_id' => katello_contentview(line[ORGANIZATION], :name => 'Default Organization View'),
              'last_checkin' => checkin_time,
              'facts' => facts(name, line),
              'installed_products' => products(line),
              'type' => 'system'
          })['uuid']

          # last_checkin is not updated in candlepin on creation
          # https://bugzilla.redhat.com/show_bug.cgi?id=1212122
          @api.resource(:systems).call(:update, {
            'id' => host_id,
            'system' => {
                'last_checkin' => checkin_time
            },
            'last_checkin' => checkin_time
          })

        else
          print(_("Updating content host '%{name}'...") % {:name => name}) if option_verbose?
          host_id = @api.resource(:systems).call(:update, {
              'id' => @existing[line[ORGANIZATION]][name],
              'system' => {
                  'name' => name,
                  'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => 'Library'),
                  'content_view_id' => katello_contentview(line[ORGANIZATION], :name => 'Default Organization View'),
                  'last_checkin' => checkin_time,
                  'facts' => facts(name, line),
                  'installed_products' => products(line)
              },
              'installed_products' => products(line),  # TODO: http://projects.theforeman.org/issues/9191
              'last_checkin' => checkin_time
          })['uuid']

          @existing[line[ORGANIZATION]].delete(name) # Remove to indicate found
        end

        if @hosts.include? line[UUID]
          @hosts[line[UUID]] = host_id
        elsif @guests.include? line[UUID]
          @guests[line[UUID]] = "#{line[ORGANIZATION]}/#{name}"
        end

        update_host_collections(host_id, line)

        puts _('done') if option_verbose?
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def facts(name, line)
        facts = {}
        facts['system.certificate_version'] = '3.2'  # Required for auto-attach to work
        facts['network.hostname'] = line[NAME]
        facts['network.ipv4_address'] = line[IP_ADDRESS]
        facts['network.ipv6_address'] = line[IPV6_ADDRESS]
        facts['memory.memtotal'] = line[MEMORY]
        facts['uname.machine'] = line[ARCHITECTURE]
        facts['virt.is_guest'] = line[IS_VIRTUALIZED] == 'Yes' ? true : false
        facts['virt.uuid'] = "#{line[ORGANIZATION]}/#{name}" if facts['virt.is_guest']

        # 1 CPUs 1 Sockets; eth0 10.11....
        hardware = line[HARDWARE].split(' ')
        if hardware[1] == 'CPUs'
          facts['cpu.cpu(s)'] = hardware[0] unless hardware[0] == 'unknown'
          facts['cpu.cpu_socket(s)'] = hardware[2] unless hardware[0] == 'unknown'
          # facts['cpu.core(s)_per_socket']  Not present in data
        end

        facts
      end

      def update_host_collections(host_id, line)
        return nil if !line[HOSTCOLLECTIONS]

        @existing_hostcollections ||= {}
        if @existing_hostcollections[line[ORGANIZATION]].nil?
          @existing_hostcollections[line[ORGANIZATION]] = {}
          @api.resource(:host_collections).call(:index, {
              :per_page => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION])
          })['results'].each do |hostcollection|
            @existing_hostcollections[line[ORGANIZATION]][hostcollection['name']] = hostcollection['id']
          end
        end

        CSV.parse_line(line[HOSTCOLLECTIONS], {:col_sep => ';'}).each do |hostcollection_name|
          if @existing_hostcollections[line[ORGANIZATION]][hostcollection_name].nil?
            hostcollection_id = @api.resource(:host_collections).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => hostcollection_name,
                'unlimited_content_hosts' => true,
                'max_content_hosts' => nil
            })['id']
            @existing_hostcollections[line[ORGANIZATION]][hostcollection_name] = hostcollection_id
          end

          @api.resource(:host_collections).call(:add_systems, {
              'id' => @existing_hostcollections[line[ORGANIZATION]][hostcollection_name],
              'system_ids' => [host_id]
          })
        end
      end

      def products(line)
        return nil if !line[PRODUCTS]
        products = CSV.parse_line(line[PRODUCTS], {:col_sep => ';'}).collect do |channel|
          product = @product_mapping[channel]
          if product.nil?
            # puts _("WARNING: No product found for channel '%{name}'") % {:name => channel}
            next
          end
          product
        end
        products.compact
      end

      def preload_host_guests
        @hosts = {}
        @guests = {}
        return unless option_dir && File.exists?(option_dir + "/host-guests")
        host_guest_file = option_dir + "/host-guests"

        CSV.foreach(host_guest_file, {
            :skip_blanks => true,
            :headers => :first_row,
            :return_headers => false
        }) do |line|
          @hosts[line['server_id']] = nil
          CSV.parse_line(line['guests'], {:col_sep => ';'}).each do |guest|
            @guests[guest] = nil
          end
        end
      end

      def update_host_guests
        return unless option_dir && File.exists?(option_dir + "/host-guests")
        return if @hosts.empty?
        host_guest_file = option_dir + "/host-guests"

        print _('Updating hypervisor and guest associations...') if option_verbose?

        CSV.foreach(host_guest_file, {
            :skip_blanks => true,
            :headers => :first_row,
            :return_headers => false
        }) do |line|
          host_id = @hosts[line['server_id']]
          next if host_id.nil?
          guest_ids = CSV.parse_line(line['guests'], {:col_sep => ';'}).collect do |guest|
            @guests[guest]
          end

          @api.resource(:systems).call(:update, {
              'id' => host_id,
              'guest_ids' => guest_ids
          })
        end

        puts _("done") if option_verbose?
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

      def create_organization(line)
        if !@existing_organizations
          @existing_organizations = {}
          @api.resource(:organizations).call(:index, {
              :per_page => 999999
          })['results'].each do |organization|
            @existing_organizations[organization['name']] = organization['id'] if organization
          end
        end

        if !@existing_organizations[line[ORGANIZATION]]
          print _("Creating organization '%{name}'... ") % {:name => line[ORGANIZATION]} if option_verbose?
          @api.resource(:organizations).call(:create, {
              'name' => line[ORGANIZATION],
              'organization' => {
                  'name' => line[ORGANIZATION],
                  'label' => "splice-#{line[ORGANIZATION_ID]}",
                  'description' => _('Satellite-5 Splice')
              }
          })
          puts _('done')
        end
      end

      def delete_unfound_hosts(hosts)
        hosts.keys.each do |organization|
          hosts[organization].values.each do |host_id|
            print _("Deleting content host with id '%{id}'...") % {:id => host_id}
            @api.resource(:systems).call(:destroy, {:id => host_id})
            puts _('done')
          end
        end
      end


      def load_product_mapping
        @product_mapping = {}

        mapping_dir = (option_mapping_dir || '/usr/share/rhsm/product/RHEL-6')
        File.open(mapping_dir + '/channel-cert-mapping.txt', 'r') do |file|
          file.each_line do |line|
            # '<product name>: <file name>\n'
            (product_name, file_name) = line.split(':')
            @product_mapping[product_name] = {:file => "#{mapping_dir}/#{file_name[1..-2]}"}
            OpenSSL::X509::Certificate.new(File.read(@product_mapping[product_name][:file])).extensions.each do |extension|
              if extension.oid.start_with?("1.3.6.1.4.1.2312.9.1.")
                oid_parts = extension.oid.split('.')
                @product_mapping[product_name][:productId] = oid_parts[-2].to_i
                case oid_parts[-1]
                when /1/
                  @product_mapping[product_name][:productName] = extension.value[2..-1] #.sub(/\A\.+/,'')
                when /2/
                  @product_mapping[product_name][:version] = extension.value[2..-1] #.sub(/\A\.+/,'')
                when /3/
                  @product_mapping[product_name][:arch] = extension.value[2..-1] #.sub(/\A\.+/,'')
                end
              end
            end
          end
        end

        channel_file = option_dir + '/cloned-channels'
        return unless File.exists? channel_file
        unmatched_channels = []
        CSV.foreach(channel_file, {
            :skip_blanks => true,
            :headers => :first_row,
            :return_headers => false
        }) do |line|
          if @product_mapping[line['original_channel_label']]
            @product_mapping[line['new_channel_label']] = @product_mapping[line['original_channel_label']]
          else
            unmatched_channels << line
          end
        end

        # Second pass through
        unmatched_channels.each do |line|
          next if @product_mapping[line['original_channel_label']].nil?
          @product_mapping[line['new_channel_label']] = @product_mapping[line['original_channel_label']]
        end
      end
    end
  end
end
