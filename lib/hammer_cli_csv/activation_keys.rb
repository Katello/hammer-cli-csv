module HammerCLICsv
  class CsvCommand
    class ActivationKeysCommand < BaseCommand
      include ::HammerCLICsv::Utils::Subscriptions

      command_name 'activation-keys'
      desc         _('import or export activation keys')

      def self.supported?
        true
      end

      option %w(--itemized-subscriptions), :flag, _('Export one subscription per row, only process update subscriptions on import')

      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      LIMIT = 'Limit'
      ENVIRONMENT = 'Environment'
      CONTENTVIEW = 'Content View'
      HOSTCOLLECTIONS = 'Host Collections'
      SERVICELEVEL = "Service Level"
      RELEASEVER = "Release Version"
      AUTOATTACH = "Auto-Attach"

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
        iterate_activationkeys(csv) do |activationkey|
          columns = shared_columns(activationkey)
          @api.resource(:subscriptions).call(:index, {
              'organization_id' => activationkey['organization']['id'],
              'activation_key_id' => activationkey['id']
          })['results'].collect do |subscription|
            subscription_type = subscription['product_id'].to_i == 0 ? 'Red Hat' : 'Custom'
            subscription_type += ' Guest' if subscription['type'] == 'STACK_DERIVED'
            subscription_type += ' Temporary' if subscription['type'] == 'UNMAPPED_GUEST'
            amount = (subscription['quantity_attached'].nil? || subscription['quantity_attached'] < 1) ? 'Automatic' : subscription['quantity_attached']
            csv << columns +
              [subscription['product_name'], subscription_type, amount,
               subscription['product_id'], subscription['contract_number'], subscription['account_number'],
               DateTime.parse(subscription['start_date']),
               DateTime.parse(subscription['end_date'])]
          end
        end
      end

      def export_all(csv)
        csv << shared_headers + [SUBSCRIPTIONS]
        iterate_activationkeys(csv) do |activationkey|
          subscriptions = CSV.generate do |column|
            column << @api.resource(:subscriptions).call(:index, {
                          'organization_id' => activationkey['organization']['id'],
                          'activation_key_id' => activationkey['id']
                      })['results'].collect do |subscription|
              amount = (subscription['quantity_attached'].nil? || subscription['quantity_attached'] < 1) ? 'Automatic' : subscription['quantity_attached']
              "#{amount}"\
              "|#{subscription['product_id']}"\
              "|#{subscription['product_name']}"\
              "|#{subscription['contract_number']}|#{subscription['account_number']}"
            end
          end
          subscriptions.delete!("\n")
          csv << shared_columns(activationkey) + [subscriptions]
        end
      end

      def iterate_activationkeys(csv)
        @api.resource(:organizations).call(:index, {
            :per_page => 999999
        })['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          @api.resource(:activation_keys).call(:index, {
              'per_page' => 999999,
              'organization_id' => organization['id']
          })['results'].each do |activationkey|
            yield activationkey
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_from_csv(line)
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

      def update_itemized_subscriptions(name, line)
        raise _("Activation key '%{name}' must already exist with --itemized_subscriptions") % {:name => name} unless @existing[line[ORGANIZATION]].include? name

        print(_("Updating subscriptions for activation key '%{name}'...") % {:name => name}) if option_verbose?
        activationkey = @api.resource(:activation_keys).call(:show, {:id => @existing[line[ORGANIZATION]][name]})
        update_subscriptions(activationkey, line, false)
        puts _('done') if option_verbose?
      end

      def update_or_create(name, line)
        params = {
                   'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                   'name' => name,
                   'environment_id' => lifecycle_environment(line[ORGANIZATION],
                                                             :name => line[ENVIRONMENT]),
                   'content_view_id' => katello_contentview(line[ORGANIZATION],
                                                            :name => line[CONTENTVIEW]),
                   'description' => line[DESCRIPTION],
                   'unlimited_content_hosts' => (line[LIMIT] == 'Unlimited') ? true : false,
                   'max_content_hosts' => (line[LIMIT] == 'Unlimited') ? nil : line[LIMIT].to_i
                 }
        params['auto_attach'] = (line[AUTOATTACH] == 'Yes' ? true : false) if params['auto_attach']
        params['service_level'] = line[SERVICELEVEL].nil? || line[SERVICELEVEL].empty? ? nil : line[SERVICELEVEL]
        params['release_version'] = line[RELEASEVER].nil? || line[RELEASEVER].empty? ? nil : line[RELEASEVER]
        if !@existing[line[ORGANIZATION]].include? name
          print _("Creating activation key '%{name}'...") % {:name => name} if option_verbose?
          activationkey = @api.resource(:activation_keys).call(:create, params)
          @existing[line[ORGANIZATION]][activationkey['name']] = activationkey['id']
        else
          print _("Updating activation key '%{name}'...") % {:name => name} if option_verbose?
          params['id'] = @existing[line[ORGANIZATION]][name]
          activationkey = @api.resource(:activation_keys).call(:update, params)
        end

        update_subscriptions(activationkey, line, true)
        update_groups(activationkey, line)

        puts _('done') if option_verbose?
      end

      def update_groups(activationkey, line)
        if line[HOSTCOLLECTIONS] && line[HOSTCOLLECTIONS] != ''
          # TODO: note that existing system groups are not removed
          CSV.parse_line(line[HOSTCOLLECTIONS], {:skip_blanks => true}).each do |name|
            @api.resource(:activation_keys).call(:add_host_collections, {
                'id' => activationkey['id'],
                'host_collection_ids' => [katello_hostcollection(line[ORGANIZATION], :name => name)]
            })
          end
        end
      end

      def update_subscriptions(activationkey, line, remove_existing)
        existing_subscriptions = @api.resource(:subscriptions).call(:index, {
            'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
            'per_page' => 999999,
            'activation_key_id' => activationkey['id']
        })['results']
        if remove_existing && existing_subscriptions.length > 0
          existing_subscriptions.map! do |existing_subscription|
            {:id => existing_subscription['id'], :quantity => existing_subscription['quantity_consumed']}
          end
          @api.resource(:activation_keys).call(:remove_subscriptions, {
            'id' => activationkey['id'],
            'subscriptions' => existing_subscriptions
          })
          existing_subscriptions = []
        end

        if line[Utils::Subscriptions::SUBS_NAME].nil? && line[Utils::Subscriptions::SUBS_SKU].nil?
          all_in_one_subscription(activationkey, existing_subscriptions, line)
        else
          single_subscription(activationkey, existing_subscriptions, line)
        end
      end

      def single_subscription(activationkey, existing_subscriptions, line)
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
                                                                       'organization_id' => activationkey['organization']['id'],
                                                                       'activation_key_id' => activationkey['id'],
                                                                       'available_for' => 'activation_key'
                                                                     })['results']

        matches = matches_by_sku_and_name([], line, available_subscriptions)
        matches = matches_by_type(matches, line)
        matches = matches_by_account(matches, line)
        matches = matches_by_contract(matches, line)
        matches = matches_by_quantity(matches, line)

        raise _("No matching subscriptions") if matches.empty?

        match = matches[0]

        match = match_with_quantity_to_attach(match, line)

        if option_verbose?
          print _(" attaching %{quantity} of '%{name}'...") % {
            :name => match['name'], :quantity => match['quantity']
          }
        end

        @api.resource(:activation_keys).call(:add_subscriptions, {
            'id' => activationkey['id'],
            'subscriptions' => [match]
        })
      end

      def all_in_one_subscription(activationkey, existing_subscriptions, line)
        return if line[SUBSCRIPTIONS].nil? || line[SUBSCRIPTIONS].empty?

        subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |details|
          (amount, sku, name, contract, account) = split_subscription_details(details)
          {
            :id => get_subscription(line[ORGANIZATION], :name => name),
            :quantity => (amount.nil? || amount == 'Automatic') ? 0 : amount.to_i
          }
        end

        @api.resource(:activation_keys).call(:add_subscriptions, {
                                               'id' => activationkey['id'],
                                               'subscriptions' => subscriptions
                                             })
      end

      def usage_limit(limit)
        Integer(limit) rescue -1
      end

      def shared_headers
        [NAME, ORGANIZATION, DESCRIPTION, LIMIT, ENVIRONMENT, CONTENTVIEW,
         HOSTCOLLECTIONS, AUTOATTACH, SERVICELEVEL, RELEASEVER]
      end

      def shared_columns(activationkey)
        name = namify(activationkey['name'])
        organization = activationkey['organization']['name']
        description = activationkey['description']
        limit = activationkey['unlimited_content_hosts'] ? 'Unlimited' : activationkey['max_content_hosts']
        environment = activationkey['environment'].nil? ? nil : activationkey['environment']['label']
        contentview = activationkey['content_view'].nil? ? nil : activationkey['content_view']['name']
        hostcollections = export_column(activationkey, 'host_collections', 'name')
        autoattach = activationkey['auto_attach'] ? 'Yes' : 'No'
        servicelevel = activationkey['service_level']
        releasever = activationkey['release_version']
        [name, organization, description, limit, environment, contentview, hostcollections,
         autoattach, servicelevel, releasever]
      end

      def update_existing(line)
        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          @api.resource(:activation_keys).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION])
          })['results'].each do |activationkey|
            @existing[line[ORGANIZATION]][activationkey['name']] = activationkey['id'] if activationkey
          end
        end
      end
    end
  end
end
