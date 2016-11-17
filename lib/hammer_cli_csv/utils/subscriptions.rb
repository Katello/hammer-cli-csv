module HammerCLICsv
  module Utils
    module Subscriptions
      SUBSCRIPTIONS = 'Subscriptions'
      SUBS_NAME = 'Subscription Name'
      SUBS_TYPE = 'Subscription Type'
      SUBS_QUANTITY = 'Subscription Quantity'
      SUBS_SKU = 'Subscription SKU'
      SUBS_CONTRACT = 'Subscription Contract'
      SUBS_ACCOUNT = 'Subscription Account'
      SUBS_START = 'Subscription Start'
      SUBS_END = 'Subscription End'
      SUBS_VIRT_ONLY = 'Virt Only'

      def get_all_subscriptions(organization)
        @api.resource(:subscriptions).call(:index, {
            :per_page => 999999,
            'organization_id' => foreman_organization(:name => organization)
        })['results']
      end

      def get_subscription(organization, options = {})
        @subscriptions ||= {}
        @subscriptions[organization] ||= {}

        if options[:name]
          return nil if options[:name].nil? || options[:name].empty?
          options[:id] = @subscriptions[organization][options[:name]]
          if !options[:id]
            results = @api.resource(:subscriptions).call(:index, {
                :per_page => 999999,
                'organization_id' => foreman_organization(:name => organization),
                'search' => "name = \"#{options[:name]}\""
            })
            raise "No subscriptions match '#{options[:name]}'" if results['subtotal'] == 0
            raise "Too many subscriptions match '#{options[:name]}'" if results['subtotal'] > 1
            subscription = results['results'][0]
            @subscriptions[organization][options[:name]] = subscription['id']
            options[:id] = @subscriptions[organization][options[:name]]
            raise "Subscription '#{options[:name]}' not found" if !options[:id]
          end
          result = options[:id]
        else
          return nil if options[:id].nil?
          options[:name] = @subscriptions.key(options[:id])
          if !options[:name]
            subscription = @api.resource(:subscriptions).call(:show, {'id' => options[:id]})
            raise "Subscription '#{options[:name]}' not found" if !subscription || subscription.empty?
            options[:name] = subscription['name']
            @subscriptions[options[:name]] = options[:id]
          end
          result = options[:name]
        end

        result
      end

      def matches_by_sku_and_name(matches, line, subscriptions)
        if line[SUBS_SKU]
          matches = subscriptions.select do |subscription|
            line[SUBS_SKU] == subscription['product_id']
          end
          raise _("No subscriptions match SKU '%{sku}'") % {:sku => line[SUBS_SKU]} if matches.empty?
        elsif line[SUBS_NAME]
          matches = subscriptions.select do |subscription|
            line[SUBS_NAME] == subscription['name']
          end
          raise _("No subscriptions match name '%{name}'") % {:name => line[SUBS_NAME]} if matches.empty?
        end
        matches
      end

      def matches_by_type(matches, line)
        if line[SUBS_TYPE] == 'Red Hat' || line[SUBS_TYPE] == 'Custom'
          matches = matches.select do |subscription|
            subscription['type'] == 'NORMAL'
          end
        elsif line[SUBS_TYPE] == 'Red Hat Guest'
          matches = matches.select do |subscription|
            subscription['type'] == 'STACK_DERIVED'
          end
        elsif line[SUBS_TYPE] == 'Red Hat Temporary'
          matches = matches.select do |subscription|
            subscription['type'] == 'UNMAPPED_GUEST'
          end
        elsif line[SUBS_TYPE] == 'Red Hat Entitlement Derived'
          matches = matches.select do |subscription|
            subscription['type'] == 'ENTITLEMENT_DERIVED'
          end
        end
        raise _("No subscriptions match type '%{type}'") % {:type => line[SUBS_TYPE]} if matches.empty?
        matches
      end

      def matches_by_account(matches, line)
        if matches.length > 1 && line[SUBS_ACCOUNT]
          refined = matches.select do |subscription|
            line[SUBS_ACCOUNT] == subscription['account_number']
          end
          matches = refined unless refined.empty?
        end
        matches
      end

      def matches_by_contract(matches, line)
        if matches.length > 1 && line[SUBS_CONTRACT]
          refined = matches.select do |subscription|
            line[SUBS_CONTRACT] == subscription['contract_number']
          end
          matches = refined unless refined.empty?
        end
        matches
      end

      def matches_by_quantity(matches, line)
        if line[SUBS_QUANTITY] && line[SUBS_QUANTITY] != 'Automatic'
          refined = matches.select do |subscription|
            subscription['available'] < 0 || line[SUBS_QUANTITY].to_i <= subscription['available']
          end
          raise _("No '%{name}' subscription with quantity %{quantity} or more available") %
            {:name => matches[0]['name'], :quantity => line[SUBS_QUANTITY]} if refined.empty?
          matches = refined
        end
        matches
      end

      def matches_by_virt_only(matches, line)
        if line[SUBS_VIRT_ONLY]
          refined = matches.select do |subscription|
            subscription['virt_only'].to_s == line[SUBS_VIRT_ONLY]
          end
          raise _("No '%{name}' subscription with virt_only == %{virt_only}") %
            {:name => matches[0]['name'], :virt_only => line[SUBS_VIRT_ONLY]} if refined.empty?
          matches = refined
        end
        matches
      end

      def match_with_quantity_to_attach(match, line)
        if line[SUBS_QUANTITY] && line[SUBS_QUANTITY] != 'Automatic' && !line[SUBS_QUANTITY].empty?
          match['quantity'] = line[SUBS_QUANTITY]
        else
          match['quantity'] = -1
        end
        match
      end

      # Subscription amount, SKU, name, contract number, and account number separated by '|'
      # or simply the subscription name.
      def split_subscription_details(details)
        details = details.split('|')
        details.length == 1 ? ['Automatic', nil, details[0], nil, nil] : details
      end
    end
  end
end
