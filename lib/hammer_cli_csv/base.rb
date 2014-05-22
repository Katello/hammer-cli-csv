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

require 'apipie-bindings'
require 'hammer_cli'
require 'json'
require 'csv'
require 'hammer_cli_csv/csv'

module HammerCLICsv
  class BaseCommand < HammerCLI::Apipie::Command
    option %w(-v --verbose), :flag, 'be verbose'
    option %w(--threads), 'THREAD_COUNT', 'Number of threads to hammer with', :default => 1
    option %w(--csv-export), :flag, 'Export current data instead of importing'
    option %w(--csv-file), 'FILE_NAME', 'CSV file (default to /dev/stdout with --csv-export, otherwise required)'
    option %w(--prefix), 'PREFIX', 'Prefix for all name columns'
    option %w(--server), 'SERVER', 'Server URL'
    option %w(-u --username), 'USERNAME', 'Username to access server'
    option %w(-p --password), 'PASSWORD', 'Password to access server'

    NAME = 'Name'
    COUNT = 'Count'

    def execute
      if !option_csv_file
        if option_csv_export?
          # rubocop:disable UselessAssignment
          option_csv_file = '/dev/stdout'
        else
          # rubocop:disable UselessAssignment
          option_csv_file = '/dev/stdin'
        end
      end

      @api = ApipieBindings::API.new({
                                       :uri => option_server || HammerCLI::Settings.get(:csv, :host),
                                       :username => option_username || HammerCLI::Settings.get(:csv, :username),
                                       :password => option_password || HammerCLI::Settings.get(:csv, :password),
                                       :api_version => 2
                                     })

      option_csv_export? ? export : import
      HammerCLI::EX_OK
    end

    def namify(name_format, number = 0)
      if name_format.index('%')
        name = name_format % number
      else
        name = name_format
      end
      name = "#{option_prefix}#{name}" if option_prefix
      name
    end

    def labelize(name)
      name.gsub(/[^a-z0-9\-_]/i, '_')
    end

    def thread_import(return_headers = false)
      csv = []
      CSV.foreach(option_csv_file || '/dev/stdin', {
                                                     :skip_blanks => true,
                                                     :headers => :first_row,
                                                     :return_headers => return_headers
                                                   }) do |line|
        csv << line
      end
      lines_per_thread = csv.length / option_threads.to_i + 1
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

    def foreman_organization(options = {})
      @organizations ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @organizations[options[:name]]
        if !options[:id]
          organization = @api.resource(:organizations).call(:index, {
                                                              :per_page => 999999,
                                                              'search' => "name=\"#{options[:name]}\""
                                                            })['results']
          raise "Organization '#{options[:name]}' not found" if !organization || organization.empty?
          options[:id] = organization[0]['id']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @organizations.key(options[:id])
        if !options[:name]
          organization = @api.resource(:organizations).call(:show, {'id' => options[:id]})
          raise "Organization 'id=#{options[:id]}' not found" if !organization || organization.empty?
          options[:name] = organization['name']
          @organizations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_location(options = {})
      @locations ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @locations[options[:name]]
        if !options[:id]
          location = @api.resource(:locations).call(:index, {
                                                      :per_page => 999999,
                                                      'search' => "name=\"#{options[:name]}\""
                                                    })['results']
          raise "Location '#{options[:name]}' not found" if !location || location.empty?
          options[:id] = location[0]['id']
          @locations[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @locations.key(options[:id])
        if !options[:name]
          location = @api.resource(:locations).call(:show, {'id' => options[:id]})
          raise "Location 'id=#{options[:id]}' not found" if !location || location.empty?
          options[:name] = location['name']
          @locations[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_role(options = {})
      @roles ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @roles[options[:name]]
        if !options[:id]
          role = @api.resource(:roles).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Role '#{options[:name]}' not found" if !role || role.empty?
          options[:id] = role[0]['id']
          @roles[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @roles.key(options[:id])
        if !options[:name]
          role = @api.resource(:roles).call(:show, {'id' => options[:id]})
          raise "Role 'id=#{options[:id]}' not found" if !role || role.empty?
          options[:name] = role['name']
          @roles[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_permission(options = {})
      @permissions ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @permissions[options[:name]]
        if !options[:id]
          permission = @api.resource(:permissions).call(:index, {
                                                          :per_page => 999999,
                                                          'name' => options[:name]
                                                        })['results']
          raise "Permission '#{options[:name]}' not found" if !permission || permission.empty?
          options[:id] = permission[0]['id']
          @permissions[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @permissions.key(options[:id])
        if !options[:name]
          permission = @api.resource(:permissions).call(:show, {'id' => options[:id]})
          raise "Permission 'id=#{options[:id]}' not found" if !permission || permission.empty?
          options[:name] = permission['name']
          @permissions[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_filter(role, resource, search)
      search = nil if search && search.empty?
      filters = @api.resource(:filters).call(:index, {
                                               :per_page => 999999,
                                               'search' => "role=\"#{role}\""
                                             })['results']
      filters.each do |filter|
        return filter['id'] if filter['resource_type'] == resource && filter['search'] == search
      end

      nil
    end

    def foreman_environment(options = {})
      @environments ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @environments[options[:name]]
        if !options[:id]
          environment = @api.resource(:environments).call(:index, {
                                                            :per_page => 999999,
                                                            'search' => "name=\"#{ options[:name] }\""
                                                          })['results']
          raise "Puppet environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:id] = environment[0]['id']
          @environments[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @environments.key(options[:id])
        if !options[:name]
          environment = @api.resource(:environments).call(:show, {'id' => options[:id]})
          raise "Puppet environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:name] = environment['name']
          @environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_operatingsystem(options = {})
      @operatingsystems ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @operatingsystems[options[:name]]
        if !options[:id]
          (osname, major, minor) = split_os_name(options[:name])
          search = "name=\"#{osname}\" and major=\"#{major}\" and minor=\"#{minor}\""
          operatingsystems = @api.resource(:operatingsystems).call(:index, {
                                                                     :per_page => 999999,
                                                                     'search' => search
                                                                   })['results']
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
          operatingsystem = @api.resource(:operatingsystems).call(:show, {'id' => options[:id]})
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

    def foreman_architecture(options = {})
      @architectures ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @architectures[options[:name]]
        if !options[:id]
          architecture = @api.resource(:architectures).call(:index, {
                                                              :per_page => 999999,
                                                              'search' => "name=\"#{options[:name]}\""
                                                            })['results']
          raise "Architecture '#{options[:name]}' not found" if !architecture || architecture.empty?
          options[:id] = architecture[0]['id']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @architectures.key(options[:id])
        if !options[:name]
          architecture = @api.resource(:architectures).call(:show, {'id' => options[:id]})
          raise "Architecture 'id=#{options[:id]}' not found" if !architecture || architecture.empty?
          options[:name] = architecture['name']
          @architectures[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_domain(options = {})
      @domains ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @domains[options[:name]]
        if !options[:id]
          domain = @api.resource(:domains).call(:index, {
                                                  :per_page => 999999,
                                                  'search' => "name=\"#{options[:name]}\""
                                                })['results']
          raise "Domain '#{options[:name]}' not found" if !domain || domain.empty?
          options[:id] = domain[0]['id']
          @domains[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @domains.key(options[:id])
        if !options[:name]
          domain = @api.resource(:domains).call(:show, {'id' => options[:id]})
          raise "Domain 'id=#{options[:id]}' not found" if !domain || domain.empty?
          options[:name] = domain['name']
          @domains[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_partitiontable(options = {})
      @ptables ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @ptables[options[:name]]
        if !options[:id]
          ptable = @api.resource(:ptables).call(:index, {
                                                  :per_page => 999999,
                                                  'search' => "name=\"#{options[:name]}\""
                                                })['results']
          raise "Partition table '#{options[:name]}' not found" if !ptable || ptable.empty?
          options[:id] = ptable[0]['id']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:id]
      elsif options[:id]
        return nil if options[:id].nil?
        options[:name] = @ptables.key(options[:id])
        if !options[:name]
          ptable = @api.resource(:ptables).call(:show, {'id' => options[:id]})
          options[:name] = ptable['name']
          @ptables[options[:name]] = options[:id]
        end
        result = options[:name]
      elsif !options[:name] && !options[:id]
        result = ''
      end

      result
    end

    def lifecycle_environment(organization, options = {})
      @lifecycle_environments ||= {}
      @lifecycle_environments[organization] ||= {
      }

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @lifecycle_environments[organization][options[:name]]
        if !options[:id]
          @api.resource(:lifecycle_environments).call(:index, {
                                                        :per_page => 999999,
                                                        'organization_id' => foreman_organization(:name => organization),
                                                      })['results'].each do |environment|
            @lifecycle_environments[organization][environment['name']] = environment['id']
          end
          options[:id] = @lifecycle_environments[organization][options[:name]]
          raise "Lifecycle environment '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @lifecycle_environments.key(options[:id])
        if !options[:name]
          environment = @api.resource(:lifecycle_environments).call(:show, {'id' => options[:id]})
          raise "Lifecycle environment '#{options[:name]}' not found" if !environment || environment.empty?
          options[:name] = environment['name']
          @lifecycle_environments[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_contentview(organization, options = {})
      @contentviews ||= {}
      @contentviews[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @contentviews[organization][options[:name]]
        if !options[:id]
          @api.resource(:content_views).call(:index, {
                                               :per_page => 999999,
                                               'organization_id' => foreman_organization(:name => organization)
                                             })['results'].each do |contentview|
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
          contentview = @api.resource(:content_views).call(:show, {'id' => options[:id]})
          raise "Puppet contentview '#{options[:name]}' not found" if !contentview || contentview.empty?
          options[:name] = contentview['name']
          @contentviews[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_subscription(organization, options = {})
      @subscriptions ||= {}
      @subscriptions[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @subscriptions[organization][options[:name]]
        if !options[:id]
          results = @api.resource(:subscriptions).call(:index, {
                                                         :per_page => 999999,
                                                         'organization_id' => foreman_organization(:name => organization),
                                                         'search' => "name:\"#{options[:name]}\""
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

    def katello_hostcollection(organization, options = {})
      @hostcollections ||= {}
      @hostcollections[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @hostcollections[organization][options[:name]]
        if !options[:id]
          @api.resource(:host_collections).call(:index,
                  {
                    :per_page => 999999,
                    'organization_id' => foreman_organization(:name => organization),
                    'search' => "name:\"#{options[:name]}\""
                  })['results'].each do |hostcollection|
            @hostcollections[organization][hostcollection['name']] = hostcollection['id'] if hostcollection
          end
          options[:id] = @hostcollections[organization][options[:name]]
          raise "System group '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @hostcollections.key(options[:id])
        if !options[:name]
          hostcollection = @api.resource(:host_collections).call(:show, {'id' => options[:id]})
          raise "System group '#{options[:name]}' not found" if !hostcollection || hostcollection.empty?
          options[:name] = hostcollection['name']
          @hostcollections[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def build_os_name(name, major, minor)
      name += " #{major}" if major && major != ''
      name += ".#{minor}" if minor && minor != ''
      name
    end

    # "Red Hat 6.4" => "Red Hat", "6", "4"
    # "Red Hat 6"   => "Red Hat", "6", ''
    def split_os_name(name)
      tokens = name.split(' ')
      is_number = Float(tokens[-1]) rescue false
      if is_number
        (major, minor) = tokens[-1].split('.').flatten
        name = tokens[0...-1].join(' ')
      else
        name = tokens.join(' ')
      end
      [name, major || '', minor || '']
    end

    def export_column(object, name, field)
      return '' unless object[name]
      values = CSV.generate do |column|
        column << object[name].collect do |fields|
          fields[field]
        end
      end
      values.delete!("\n")
    end

    def collect_column(column)
      return [] if column.nil? || column.empty?
      CSV.parse_line(column, {:skip_blanks => true}).collect do |value|
        yield value
      end
    end

    def pluralize(name)
      case name
      when /smart_proxy/
        'smart_proxies'
      else
        "#{name}s"
      end
    end

    def associate_organizations(id, organizations, name)
      return if organizations.nil?

      associations ||= {}
      CSV.parse_line(organizations).each do |organization|
        organization_id = foreman_organization(:name => organization)
        if associations[organization].nil?
          associations[organization] = @api.resource(:organizations).call(:show, {'id' => organization_id})[pluralize(name)].collect do |reference_object|
            reference_object['id']
          end
        end
        associations[organization] += [id] if !associations[organization].include? id
        @api.resource(:organizations)
          .call(:update, {
                  'id' => organization_id,
                  'organization' => {
                    "#{name}_ids" => associations[organization]
                  }
                })
      end if organizations && !organizations.empty?
    end

    def associate_locations(id, locations, name)
      return if locations.nil?

      associations ||= {}
      CSV.parse_line(locations).each do |location|
        location_id = foreman_location(:name => location)
        if associations[location].nil?
          associations[location] = @api.resource(:locations).call(:show, {'id' => location_id})[pluralize(name)].collect do |reference_object|
            reference_object['id']
          end
        end
        associations[location] += [id] if !associations[location].include? id

        @api.resource(:locations)
          .call(:update, {
                  'id' => location_id,
                  'location' => {
                    "#{name}_ids" => associations[location]
                  }
                })
      end if locations && !locations.empty?
    end
  end
end
