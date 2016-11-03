require 'rest_client'

module HammerCLICsv
  class CsvCommand
    class SubscriptionsCommand < BaseCommand
      include ::HammerCLICsv::Utils::Subscriptions

      command_name 'subscriptions'
      desc         'import or export subscriptions'

      def self.supported?
        true
      end

      option %w(--in-portal), :flag, _('Import subscription comment lines into portal'),
             :hidden => true
      option %w(--portal-username), 'PORTAL_USERNAME', 'Portal username',
             :hidden => true
      option %w(--portal-password), 'PORTAL_PASSWORD', 'Portal password',
             :hidden => true
      option %w(--portal-hock), 'PORTAL_HOCK', 'Portal subscription creation address',
             :hidden => true
      option %w(--portal), 'PORTAL', 'Portal subscription access address',
             :default => "https://subscription.rhn.redhat.com:443",
             :hidden => true

      ORGANIZATION = 'Organization'
      MANIFEST = 'Manifest File'

      def export(csv)
        csv << [NAME, ORGANIZATION, MANIFEST, SUBS_NAME, SUBS_QUANTITY, SUBS_SKU, SUBS_CONTRACT, SUBS_ACCOUNT, SUBS_START, SUBS_END]
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization
          organization = @api.resource(:organizations).call(:show, {'id' => organization['id']})
          export_manifest(csv, organization)
          export_subscriptions(csv, organization)
        end
      end

      def export_manifest(csv, organization)
        info = organization['owner_details']['upstreamConsumer']
        return if info.nil?

        csv << ["Manifest Name", organization['name'], info['name']]
        csv << ["Manifest URL", organization['name'], "https://#{info['webUrl']}#{info['uuid']}"]
      end

      def export_subscriptions(csv, organization)
        @api.resource(:subscriptions).call(:index, {
            'per_page' => 999999,
            'organization_id' => organization['id']
        })['results'].each do |subscription|
          next if subscription['product_id'].to_i != 0  # Red Hat subs do not have number SKU
          name = subscription['host'].nil? ? "Subscription" : "Guest Subscription for Host '#{subscription['host']['name']}'"
          quantity = subscription['quantity'] < 0 ? "Unlimited" : subscription['quantity']
          csv << [name, organization['name'], nil, subscription['name'],
                  quantity, subscription['product_id'], subscription['contract_number'],
                  subscription['account_number'],
                  subscription['start_date'], subscription['end_date']]
        end
      end

      def import
        if option_in_portal?
          import_into_portal
        else
          thread_import do |line|
            if line[NAME] == 'Manifest' && line[MANIFEST] && !line[MANIFEST].empty?
              import_manifest(line[ORGANIZATION], line[MANIFEST])
            end
          end
        end
      end

      def import_manifest(organization_name, filename)
        return if option_organization && organization_name != option_organization
        print(_("Importing manifest '%{filename}' into organization '%{organization}'...") % {:filename => filename, :organization => organization_name}) if option_verbose?
        args = %W{
          --server #{ @server } --username #{ @username } --password #{ @password }
          subscription upload --file #{ filename }
          --organization-id #{ foreman_organization(:name => organization_name) }
        }
        hammer.run(args)
        puts(_("done")) if option_verbose?
      end

      def import_into_portal
        raise _("--portal-username and --portal-password required") unless option_portal_username && option_portal_password
        raise _("--portal required") unless option_portal

        @manifests = {}

        thread_import do |line|
          return if option_organization && line[ORGANIZATION] != option_organization

          @manifests[line[ORGANIZATION]] ||= {}
          import_subscription(line)
        end

        @manifests.each do |organization, manifest|
          print _("Downloading manifest for organization '%{organization}...") % {:organization => organization} if option_verbose?
          api = rest_client("/subscription/consumers/#{manifest[:manifest]['uuid']}/export")
          data = api.get({'accept' => 'application/zip'})
          filename = manifest[:file] || "#{manifest[:name]}.zip"
          print _("writing to file '%{filename}'...") % {:filename => filename} if option_verbose?
          File.open(filename, 'w') do |f|
            f.binmode
            f.write data
          end
          puts _("done") if option_verbose?
          import_manifest(organization, filename)
        end
      end

      def import_subscription(line)
        case line[NAME]
        when "Manifest Name"
          print _("Checking manifest '%{name}'...") % {:name => line[MANIFEST]} if option_verbose?
          @manifests[line[ORGANIZATION]][:name] = line[MANIFEST]
          @manifests[line[ORGANIZATION]][:manifest] = get_or_create_manifest(line)
          puts _("done") if option_verbose?
        when "Manifest URL"
          # ignore
        when "Manifest"
          @manifests[line[ORGANIZATION]][:file] = line[MANIFEST]
        when "Subscription"
          manifest = @manifests[line[ORGANIZATION]][:manifest]
          raise _('Manifest Name row is required before updating from Subscription rows') unless manifest
          line[SUBS_QUANTITY] = line[SUBS_QUANTITY].to_i  #guarantee integer for future calculations
          add_subscription(line, manifest)
        else
          # ignore
        end
      end

      def add_subscription(line, manifest)
        if find_existing_subscription(line, manifest)
          puts _("'%{name}' of quantity %{quantity} already attached") %
                  {:name => line[SUBS_NAME], :quantity => line[SUBS_QUANTITY]} if option_verbose?
          return
        end
        print _("Attaching '%{name}' of quantity %{quantity}...") %
                {:name => line[SUBS_NAME], :quantity => line[SUBS_QUANTITY]} if option_verbose?
        manifest['available_subscriptions'] ||= get_available_subscriptions(manifest)
        attach_subscription(line, manifest)
        puts _('done')
      end

      def attach_subscription(line, manifest)
        manifest['available_subscriptions'].each do |subscription|
          if subscription['productId'] == line[SUBS_SKU] && subscription['quantity'] >= line[SUBS_QUANTITY]
            api = rest_client("/subscription/consumers/#{manifest['uuid']}/entitlements?pool=#{subscription['id']}&quantity=#{line[SUBS_QUANTITY]}")
            results = api.post({}.to_json)
            subscription['quantity'] -= line[SUBS_QUANTITY]
            return
          end
        end
        print _('subscription unavailable...')
      end

      def get_available_subscriptions(manifest)
        api = rest_client("/subscription/pools/?consumer=#{manifest['uuid']}&listall=false")
        JSON.parse(api.get)
      end

      def find_existing_subscription(line, manifest)
        manifest['subscriptions'].each do |subscription|
          if !subscription['csv_matched'] && subscription['pool']['productId'] == line[SUBS_SKU] && subscription['quantity'] == line[SUBS_QUANTITY]
            subscription['csv_matched'] = true
            return true
          end
        end
        false
      end

      def get_or_create_manifest(line)
        manifest = get_existing_manifest(line)
        if manifest
          if manifest['subscriptions'].nil?
            api = rest_client("/subscription/consumers/#{manifest['uuid']}/entitlements")
            results = JSON.parse(api.get)
            manifest['subscriptions'] = results
          end
        else
          api = rest_client("/subscription/consumers?owner=#{@manifests[line[ORGANIZATION]][:owner]}")
          body = {
            'name' => line[MANIFEST],
            'type' => 'satellite',
            'facts' => {
              'distributor_version' => 'sat-6.0',
              'system.certificate_version' => '3.2'
            }
          }
          results = api.post(body.to_json,
              {'accept' => 'json', 'content_type' => 'application/json'}
          )
          manifest = JSON.parse(results)
          manifest['subscriptions'] = []
          @manifests[line[ORGANIZATION]][:manifest] = manifest
        end
        manifest
      end

      def get_existing_manifest(line)
        return @manifests[line[ORGANIZATION]][:manifest] if @manifests[line[ORGANIZATION]][:manifest]

        unless @manifests[line[ORGANIZATION]][:owner]
          api = rest_client("/subscription/users/#{option_portal_username}/owners")
          @manifests[line[ORGANIZATION]][:owner] = JSON.parse(api.get)[0]['key']
        end

        api = rest_client("/subscription/owners/#{@manifests[line[ORGANIZATION]][:owner]}/consumers?type=satellite")
        response = JSON.parse(api.get).each do |manifest|
          if manifest['name'] == @manifests[line[ORGANIZATION]][:name]
            @manifests[line[ORGANIZATION]][:manifest] = manifest
            break
          end
        end
        @manifests[line[ORGANIZATION]][:manifest]
      end

      def rest_client(path)
        options = {
          :headers => {
            'accept' => 'application/json',
            'accept-language' => HammerCLI::I18n.locale,
            'content-type' => 'application/json'
          },
          :user => option_portal_username,
          :password => option_portal_password,
          :verify_ssl => OpenSSL::SSL::VERIFY_NONE
        }

        RestClient::Resource.new(option_portal + path, options)
      end
    end
  end
end
