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
      SUBS_GUESTOF = 'Subscription Guest'

      def get_all_subscriptions(organization)
        @api.resource(:subscriptions).call(:index, {
            'full_results' => true,
            'organization_id' => foreman_organization(:name => organization)
        })['results']
      end

      def get_matching_subscriptions(organization_id, options = {})
        logger.debug("get_matching_subscriptions: #{options}")
        if options[:host]
          available_subscriptions = @api.resource(:subscriptions).call(:index, {
            'full_results' => true,
            'organization_id' => organization_id,
            'host_id' => options[:host]['id'],
            'available_for' => 'host',
            'match_host' => true
          })['results']
        elsif options[:activation_key]
          available_subscriptions = @api.resource(:subscriptions).call(:index, {
            'full_results' => true,
            'organization_id' => organization_id,
            'activation_key_id' => options[:activation_key]['id'],
            'available_for' => 'activation_key'
          })['results']
        else
          available_subscriptions = @api.resource(:subscriptions).call(:index, {
              'full_results' => true,
              'organization_id' => organization_id
          })['results']
        end

        debug_subscriptions('available_subscriptions', available_subscriptions)
        matches = matches_by_sku_and_name([], options[:sku], options[:name], available_subscriptions)
        matches = matches_by_type(matches, options[:type])
        matches = matches_by_hypervisor(matches, options[:hypervisor])
        matches = matches_by_account(matches, options[:account])
        matches = matches_by_contract(matches, options[:contract])
        matches = matches_by_sla(matches, options[:sla])
        matches = matches_by_quantity(matches, options[:quantity]) unless options[:activation_key]

        matches
      end

      def matches_by_sku_and_name(matches, subs_sku, subs_name, subscriptions)
        return matches if subscriptions.empty?

        if subs_sku
          matches = subscriptions.select do |subscription|
            subs_sku == subscription['product_id']
          end
          raise _("No subscriptions match SKU '%{sku}'") % {:sku => subs_sku} if matches.empty?
        elsif subs_name
          matches = subscriptions.select do |subscription|
            subs_name == subscription['name']
          end
        end
        debug_subscriptions("matches_by_sku_and_name: #{subs_sku}|#{subs_name}", matches)
        matches
      end

      def matches_by_hypervisor(matches, subs_hypervisor)
        return matches if matches.empty?

        if !subs_hypervisor.nil? && !subs_hypervisor.empty?
          matches.select! do |subscription|
            !subscription['host'].nil? && subscription['host']['name'] == subs_hypervisor
          end
          if matches.empty? && subs_hypervisor =~ /virt-who-/
            subs_hypervisor = subs_hypervisor.split('-')[2..-2].join('-')
            matches.select! do |subscription|
              !subscription['host'].nil? && subscription['host']['name'] == subs_hypervisor
            end
          end
        else
          matches.select! do |subscription|
            subscription['host'].nil?
          end
        end
        debug_subscriptions("matches_by_hypervisor: #{subs_hypervisor}", matches)
        matches
      end

      def matches_by_sla(matches, subs_sla)
        return matches if matches.empty?

        if !subs_sla.nil? && !subs_sla.empty?
          found = matches.select do |subscription|
            subscription['sla'] == subs_sla
          end
          # Fallback to subscriptions w/o sla set
          if found.empty?
            found = matches.select do |subscription|
              subscription['sla'].nil? || subscription['sla'].empty?
            end
          end
          matches = found
        end
        debug_subscriptions("matches_by_sla: #{subs_sla}", matches)
        matches
      end

      def matches_by_type(matches, subs_type)
        return matches if matches.empty?

        if subs_type == 'Red Hat' || subs_type == 'Custom'
          matches.select! do |subscription|
            subscription['type'] == 'NORMAL'
          end
        elsif subs_type == 'Red Hat Guest'
          matches.select! do |subscription|
            !subscription['host'].nil? && !subscription['host'].empty?
          end
        elsif subs_type == 'Red Hat Temporary'
          matches.select! do |subscription|
            subscription['type'] == 'UNMAPPED_GUEST'
          end
        end
        debug_subscriptions("matches_type: #{subs_type}", matches)
        matches
      end

      def matches_by_account(matches, subs_account)
        return matches if matches.empty?

        if matches.length > 1 && subs_account
          refined = matches.select do |subscription|
            subs_account == subscription['account_number']
          end
          matches = refined unless refined.empty?
        end
        debug_subscriptions("matches_by_account: #{subs_account}", matches)
        matches
      end

      def matches_by_contract(matches, subs_contract)
        return matches if matches.empty?

        if matches.length > 1 && subs_contract
          refined = matches.select do |subscription|
            subs_contract == subscription['contract_number']
          end
          matches = refined unless refined.empty?
        end
        debug_subscriptions("matches_by_contract: #{subs_contract}", matches)
        matches
      end

      def matches_by_quantity(matches, subs_quantity)
        return matches if matches.empty?

        matches.select! do |subscription|
          subscription['available'] != 0
        end

        if !subs_quantity.nil? && !subs_quantity.empty? && subs_quantity != 'Automatic'
          subs_quantity = subs_quantity.to_i
          matches.select! do |subscription|
            subscription['available'] < 0 || subs_quantity <= subscription['available']
          end
        end
        debug_subscriptions("matches_by_quantity: #{subs_quantity}", matches)
        matches
      end

      def match_with_quantity_to_attach(match, subs_quantity)
        if subs_quantity && subs_quantity != 'Automatic' && !subs_quantity.empty?
          match['quantity'] = subs_quantity
        else
          match['quantity'] = -1
        end
        match
      end

      def subscription_name(subscription)
        if subscription['host'].nil?
          subscription['name']
        else
          "#{subscription['name']} - Guest of #{subscription['host']['name']}"
        end
      end

      # Subscription amount, SKU, name, contract number, and account number separated by '|'
      # or simply the subscription name.
      def split_subscription_details(details)
        details = details.split('|')
        details.length == 1 ? ['Automatic', nil, details[0], nil, nil] : details
      end

      def debug_subscriptions(description, subscriptions)
        logger.debug(description)
        subscriptions.each do |subscription|
          logger.debug "#{subscription['quantity_consumed']}"\
                       "|#{subscription['product_id']}"\
                       "|#{subscription['product_name']}"\
                       "|#{subscription['contract_number']}|#{subscription['account_number']}"
        end
      end
    end
  end
end
