# Copyright (c) 2013-2014 Red Hat
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

require 'hammer_cli'
require 'katello_api'
require 'foreman_api'
require 'json'
require 'csv'

module HammerCLICsv
  class BaseCommand < HammerCLI::AbstractCommand

    NAME = 'Name'
    COUNT = 'Count'

    option ["-v", "--verbose"], :flag, "be verbose"
    option ['--threads'], 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
    option ['--csv-export'], :flag, 'Export current data instead of importing'
    option ['--csv-file'], 'FILE_NAME', 'CSV file (default to /dev/stdout with --csv-export, otherwise required)'
    option ['--prefix'], 'PREFIX', 'Prefix for all name columns'
    option ['--server'], 'SERVER', 'Server URL'
    option ['-u', '--username'], 'USERNAME', 'Username to access server'
    option ['-p', '--password'], 'PASSWORD', 'Password to access server'

    def execute
      if !option_csv_file
        if option_csv_export?
          option_csv_file = '/dev/stdout'
        else
          option_csv_file = '/dev/stdin'
        end
      end

      @init_options = {
        :base_url => option_server   || HammerCLI::Settings.get(:host),
        :username => option_username || HammerCLI::Settings.get(:username),
        :password => option_password || HammerCLI::Settings.get(:password)
      }

      @k_system_api ||= KatelloApi::Resources::System.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_systemgroup_api ||= KatelloApi::Resources::SystemGroup.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_environment_api ||= KatelloApi::Resources::Environment.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_contentview_api ||= KatelloApi::Resources::ContentView.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_provider_api ||= KatelloApi::Resources::Provider.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_product_api ||= KatelloApi::Resources::Product.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_repository_api ||= KatelloApi::Resources::Repository.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_contentviewdefinition_api ||= KatelloApi::Resources::ContentViewDefinition.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_subscription_api ||= KatelloApi::Resources::Subscription.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_organization_api ||= KatelloApi::Resources::Organization.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))
      @k_activationkey_api ||= KatelloApi::Resources::ActivationKey.new(@init_options.merge({:base_url => "#{@init_options[:base_url]}"}))

      @f_architecture_api ||= ForemanApi::Resources::Architecture.new(@init_options)
      @f_domain_api ||= ForemanApi::Resources::Domain.new(@init_options)
      @f_environment_api ||= ForemanApi::Resources::Environment.new(@init_options)
      @f_filter_api ||= ForemanApi::Resources::Filter.new(@init_options)
      @f_host_api ||= ForemanApi::Resources::Host.new(@init_options)
      @f_location_api ||= ForemanApi::Resources::Location.new(@init_options)
      @f_operatingsystem_api ||= ForemanApi::Resources::OperatingSystem.new(@init_options)
      @f_organization_api ||= ForemanApi::Resources::Organization.new(@init_options)
      @f_permission_api ||= ForemanApi::Resources::Permission.new(@init_options)
      @f_partitiontable_api ||= ForemanApi::Resources::Ptable.new(@init_options)
      @f_puppetfacts_api ||= ForemanApi::Resources::FactValue.new(@init_options)
      @f_role_api ||= ForemanApi::Resources::Role.new(@init_options)
      @f_user_api ||= ForemanApi::Resources::User.new(@init_options)

      option_csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def get_lines(filename)
      file = File.open(filename ,'r')
      contents = file.readlines
      file.close
      contents
    end

    def namify(name_format, number=0)
      if name_format.index('%')
        name = name_format % number
      else
        name = name_format
      end
      name = "#{option_prefix}#{name}" if option_prefix
      name
    end

    def labelize(name)
      name.gsub(/[^a-z0-9\-_]/i, "_")
    end

    def thread_import(return_headers=false)
      csv = []
      CSV.foreach(option_csv_file || '/dev/stdin', {:skip_blanks => true, :headers => :first_row, 
                    :return_headers => return_headers}) do |line|
        csv << line
      end
      lines_per_thread = csv.length/option_threads.to_i + 1
      splits = []

      option_threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        lines = csv[start_index...finish_index].clone
        splits << Thread.new do
          lines.each do |line|
            if line[NAME][0] != '#'
              yield line
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end
    end

    def foreman_organization(options={})
      @organizations ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @organizations[options[:name]]
        if !options[:id]
          organization = @f_organization_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise RuntimeError, "Organization '#{options[:name]}' not found" if !organization || organization.empty?
          options[:id] = organization[0]['id']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @organizations.key(options[:id])
        if !options[:name]
          organization = @f_organization_api.show({'id' => options[:id]})[0]
          raise "Organization 'id=#{options[:id]}' not found" if !organization || organization.empty?
          options[:name] = organization['name']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_location(options={})
      @locations ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @locations[options[:name]]
        if !options[:id]
          location = @f_location_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise RuntimeError, "Location '#{options[:name]}' not found" if !location || location.empty?
          options[:id] = location[0]['id']
          @locations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @locations.key(options[:id])
        if !options[:name]
          location = @f_location_api.show({'id' => options[:id]})[0]
          raise "Location 'id=#{options[:id]}' not found" if !location || location.empty?
          options[:name] = location['name']
          @locations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_permission(options={})
      @permissions ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @permissions[options[:name]]
        if !options[:id]
          permission = @f_permission_api.index({'name' => options[:name]})[0]['results']
          raise RuntimeError, "Permission '#{options[:name]}' not found" if !permission || permission.empty?
          options[:id] = permission[0]['id']
          @permissions[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @permissions.key(options[:id])
        if !options[:name]
          permission = @f_permission_api.show({'id' => options[:id]})[0]
          raise "Permission 'id=#{options[:id]}' not found" if !permission || permission.empty?
          options[:name] = permission['name']
          @permissions[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_filter(role, options={})
      @filters ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @filters[options[:name]]
        if !options[:id]
          filter = @f_filter_api.index({'search' => "role=\"#{role}\" and search=\"#{options[:name]}\""})[0]['results']
          if !filter || filter.empty?
            options[:id] = nil
          else
            options[:id] = filter[0]['id']
            @filters[options[:name]] = options[:id]
          end
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @filters.key(options[:id])
        if !options[:name]
          filter = @f_filter_api.show({'id' => options[:id]})[0]
          raise "Filter 'id=#{options[:id]}' not found" if !filter || filter.empty?
          options[:name] = filter['name']
          @filters[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_environment(options={})
      @environments ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @environments[options[:name]]
        if !options[:id]
          environment = @f_environment_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise "Puppet environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:id] = environment[0]['id']
          @environments[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @f_environment_api.show({'id' => options[:id]})[0]
          raise "Puppet environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:name] = environment['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_operatingsystem(options={})
      @operatingsystems ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @operatingsystems[options[:name]]
        if !options[:id]
          (osname, major, minor) = split_os_name(options[:name])
          search = "name=\"#{osname}\" and major=\"#{major}\" and minor=\"#{minor}\""
          operatingsystems = @f_operatingsystem_api.index({'search' => search})[0]['results']
          operatingsystem = operatingsystems[0]
          raise "Operating system '#{options[:name]}' not found" if !operatingsystem || operatingsystem.empty?
          options[:id] = operatingsystem['id']
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @operatingsystems.key(options[:id])
        if !options[:name]
          operatingsystem = @f_operatingsystem_api.show({'id' => options[:id]})[0]
          raise "Operating system 'id=#{options[:id]}' not found" if !operatingsystem || operatingsystem.empty?
          options[:name] = build_os_name(operatingsystem['name'],
                                         operatingsystem['major'],
                                         operatingsystem['minor'])
          @operatingsystems[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_architecture(options={})
      @architectures ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @architectures[options[:name]]
        if !options[:id]
          architecture = @f_architecture_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise "Architecture '#{options[:name]}' not found" if !architecture || architecture.empty?
          options[:id] = architecture[0]['id']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @architectures.key(options[:id])
        if !options[:name]
          architecture = @f_architecture_api.show({'id' => options[:id]})[0]
          raise "Architecture 'id=#{options[:id]}' not found" if !architecture || architecture.empty?
          options[:name] = architecture['name']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_domain(options={})
      @domains ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @domains[options[:name]]
        if !options[:id]
          domain = @f_domain_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise "Domain '#{options[:name]}' not found" if !domain || domain.empty?
          options[:id] = domain[0]['id']
          @domains[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @domains.key(options[:id])
        if !options[:name]
          domain = @f_domain_api.show({'id' => options[:id]})[0]
          raise "Domain 'id=#{options[:id]}' not found" if !domain || domain.empty?
          options[:name] = domain['name']
          @domains[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_partitiontable(options={})
      @ptables ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @ptables[options[:name]]
        if !options[:id]
          ptable = @f_partitiontable_api.index({'search' => "name=\"#{options[:name]}\""})[0]['results']
          raise "Partition table '#{options[:name]}' not found" if !ptable || ptable.empty?
          options[:id] = ptable[0]['id']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:id]
      elsif options[:id]
        return nil if options[:id].nil?
        options[:name] = @ptables.key(options[:id])
        if !options[:name]
          ptable = @f_partitiontable_api.show({'id' => options[:id]})[0]
          options[:name] = ptable['name']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:name]
      elsif !options[:name] && !options[:id]
        result = ''
      end

      result
    end

    def katello_environment(organization, options={})
      @environments ||= {}
      @environments[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @environments[organization][options[:name]]
        if !options[:id]
          @k_environment_api.index({'organization_id' => organization})[0]['results'].each do |environment|
            @environments[organization][environment['name']] = environment['id']
          end
          options[:id] = @environments[organization][options[:name]]
          raise "Lifecycle environment '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @k_environment_api.show({'id' => options[:id]})[0]
          raise "Lifecycle environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:name] = environment['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_contentview(organization, options={})
      @contentviews ||= {}
      @contentviews[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @contentviews[organization][options[:name]]
        if !options[:id]
          @k_contentview_api.index({'organization_id' => organization})[0]['results'].each do |contentview|
            @contentviews[organization][contentview['name']] = contentview['id']
          end
          options[:id] = @contentviews[organization][options[:name]]
          raise "Content view '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @contentviews.key(options[:id])
        if !options[:name]
          contentview = @k_contentview_api.show({'id' => options[:id]})[0]
          raise "Puppet contentview '#{options[:name]}' not found" if !contentview || contentview.empty?
          options[:name] = contentview['name']
          @contentviews[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_subscription(organization, options={})
      @subscriptions ||= {}
      @subscriptions[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @subscriptions[organization][options[:name]]
        if !options[:id]
          results = @k_subscription_api.index({
                                                'organization_id' => organization,
                                                'search' => "name:\"#{options[:name]}\""
                                              })[0]
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
          subscription = @k_subscription_api.show({'id' => options[:id]})[0]
          raise "Subscription '#{options[:name]}' not found" if !subscription || subscription.empty?
          options[:name] = subscription['name']
          @subscriptions[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_systemgroup(organization, options={})
      @systemgroups ||= {}
      @systemgroups[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @systemgroups[organization][options[:name]]
        if !options[:id]
          @k_systemgroup_api.index({
                                     'organization_id' => organization,
                                     'search' => "name:\"#{options[:name]}\""
                                   })[0]['results'].each do |systemgroup|
            @systemgroups[organization][systemgroup['name']] = systemgroup['id'] if systemgroup
          end
          options[:id] = @systemgroups[organization][options[:name]]
          raise "System group '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @systemgroups.key(options[:id])
        if !options[:name]
          systemgroup = @k_systemgroup_api.show({'id' => options[:id]})[0]
          raise "System group '#{options[:name]}' not found" if !systemgroup || systemgroup.empty?
          options[:name] = systemgroup['name']
          @systemgroups[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def build_os_name(name, major, minor)
      name += " #{major}" if major && major != ""
      name += ".#{minor}" if minor && minor != ""
      name
    end

    def split_os_name(name)
      (name, major, minor) = name.split(' ').collect {|s| s.split('.')}.flatten
      [name, major || "", minor || ""]
    end
  end
end
