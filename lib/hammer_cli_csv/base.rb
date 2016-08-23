require 'apipie-bindings'
require 'hammer_cli'
require 'json'
require 'open-uri'
require 'csv'
require 'hammer_cli_csv/csv'

# rubocop:disable ClassLength
module HammerCLICsv
  class BaseCommand < HammerCLI::Apipie::Command
    option %w(-v --verbose), :flag, 'be verbose'
    option %w(--threads), 'THREAD_COUNT', 'Number of threads to hammer with',
           :default => 1, :hidden => true
    option %w(--export), :flag, 'Export current data instead of importing'
    option %w(--file), 'FILE_NAME', 'CSV file (default to /dev/stdout with --export, otherwise required)'
    option %w(--prefix), 'PREFIX', 'Prefix for all name columns',
           :hidden => true
    option %w(--organization), 'ORGANIZATION', _('Only process organization matching this name')
    option %w(--continue-on-error), :flag, _('Continue processing even if individual resource error')

    option %w(--csv-file), 'FILE_NAME', 'Option --csv-file is deprecated. Use --file',
           :deprecated => "Use --file", :hidden => true,
           :attribute_name => :option_file
    option %w(--csv-export), :flag, 'Option --csv-export is deprecated. Use --export',
           :deprecated => "Use --export", :hidden => true,
           :attribute_name => :option_export

    NAME = 'Name'
    COUNT = 'Count'

    def self.supported?
      false
    end

    def supported?
      self.class.supported?
    end

    def help
      print_message _('**** This command is unsupported and is provided as tech preview. ****') unless supported?
      super
    end

    def execute
      @server = (HammerCLI::Settings.settings[:_params] &&
                 HammerCLI::Settings.settings[:_params][:host]) ||
        HammerCLI::Settings.get(:csv, :host) ||
        HammerCLI::Settings.get(:katello, :host) ||
        HammerCLI::Settings.get(:foreman, :host)
      @username = (HammerCLI::Settings.settings[:_params] &&
                   HammerCLI::Settings.settings[:_params][:username]) ||
        HammerCLI::Settings.get(:csv, :username) ||
        HammerCLI::Settings.get(:katello, :username) ||
        HammerCLI::Settings.get(:foreman, :username)
      @password = (HammerCLI::Settings.settings[:_params] &&
                   HammerCLI::Settings.settings[:_params][:password]) ||
        HammerCLI::Settings.get(:csv, :password) ||
        HammerCLI::Settings.get(:katello, :password) ||
        HammerCLI::Settings.get(:foreman, :password)

      @server_status = check_server_status(@server, @username, @password)

      if @server_status['release'] == 'Headpin'
        @headpin = HeadpinApi.new({
                                    :server => @server,
                                    :username => @username,
                                    :password => @password
                                  })
      else
        @api = ApipieBindings::API.new({
                                         :uri => @server,
                                         :username => @username,
                                         :password => @password,
                                         :api_version => 2
                                       })
      end

      if option_export?
        if option_file
          CSV.open(option_file, 'wb', {:force_quotes => false}) do |csv|
            export csv
          end
        else
          CSV do |csv|
            export csv
          end
        end
      else
        import
      end
      HammerCLI::EX_OK
    end

    def check_server_status(server, username, password)
      url = "#{server}/api/status"
      uri = URI(url)
      nethttp = Net::HTTP.new(uri.host, uri.port)
      nethttp.use_ssl = uri.scheme == 'https'
      nethttp.verify_mode = OpenSSL::SSL::VERIFY_NONE
      server_status = nethttp.start do |http|
        request = Net::HTTP::Get.new uri.request_uri
        request.basic_auth(username, password)
        response = http.request(request)
        JSON.parse(response.body)
      end

      url = "#{server}/api/v2/plugins"
      uri = URI(url)
      nethttp = Net::HTTP.new(uri.host, uri.port)
      nethttp.use_ssl = uri.scheme == 'https'
      nethttp.verify_mode = OpenSSL::SSL::VERIFY_NONE
      server_status['plugins'] = nethttp.start do |http|
        request = Net::HTTP::Get.new uri.request_uri
        request.basic_auth(username, password)
        response = http.request(request)
        JSON.parse(response.body)['results']
      end

      server_status
    end

    def namify(name_format, number = 0)
      return '' unless name_format
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

    def thread_import(return_headers = false, filename=nil, name_column=nil)
      filename ||= option_file || '/dev/stdin'
      csv = []
      CSV.new(open(filename), {
          :skip_blanks => true,
          :headers => :first_row,
          :return_headers => return_headers
      }).each do |line|
        csv << line
      end
      lines_per_thread = csv.length / option_threads.to_i + 1
      splits = []

      option_threads.to_i.times do |current_thread|
        start_index = ((current_thread) * lines_per_thread).to_i
        finish_index = ((current_thread + 1) * lines_per_thread).to_i
        finish_index = csv.length if finish_index > csv.length
        if start_index <= finish_index
          lines = csv[start_index...finish_index].clone
          splits << Thread.new do
            lines.each do |line|
              next if line[name_column || NAME][0] == '#'
              begin
                yield line
              rescue RuntimeError => e
                message = "#{e}\n#{line}"
                option_continue_on_error? ? $stderr.puts("Error: #{message}") : raise(message)
              end
            end
          end
        end
      end

      splits.each do |thread|
        thread.join
      end
    end

    def hammer_context
      {
        :interactive => false,
        :username => 'admin', # TODO: this needs to come from config/settings
        :password => 'changeme' # TODO: this needs to come from config/settings
      }
    end

    def hammer(context = nil)
      HammerCLI::MainCommand.new('', context || hammer_context)
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
        resource_type = (filter['resource_type'] || '').split(':')[-1] # To remove "Katello::" when present
        return filter['id'] if resource_type == resource && filter['search'] == search
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

    def foreman_template_kind(options = {})
      @template_kinds ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @template_kinds[options[:name]]
        if !options[:id]
          template_kind = @api.resource(:template_kinds).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Template kind '#{options[:name]}' not found" if !template_kind || template_kind.empty?
          options[:id] = template_kind[0]['id']
          @template_kinds[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @template_kinds.key(options[:id])
        if !options[:name]
          template_kind = @api.resource(:template_kinds).call(:show, {'id' => options[:id]})
          raise "Template kind 'id=#{options[:id]}' not found" if !template_kind || template_kind.empty?
          options[:name] = template_kind['name']
          @template_kinds[options[:name]] = options[:id]
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

    def foreman_medium(options = {})
      @media ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @media[options[:name]]
        if !options[:id]
          ptable = @api.resource(:media).call(:index, {
                                                  :per_page => 999999,
                                                  'search' => "name=\"#{options[:name]}\""
                                                })['results']
          raise "Partition table '#{options[:name]}' not found" if !ptable || ptable.empty?
          options[:id] = ptable[0]['id']
          @media[options[:name]] = options[:id]
        end
        result = options[:id]
      elsif options[:id]
        return nil if options[:id].nil?
        options[:name] = @media.key(options[:id])
        if !options[:name]
          ptable = @api.resource(:media).call(:show, {'id' => options[:id]})
          options[:name] = ptable['name']
          @media[options[:name]] = options[:id]
        end
        result = options[:name]
      elsif !options[:name] && !options[:id]
        result = ''
      end

      result
    end

    def foreman_host(options = {})
      @query_hosts ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @query_hosts[options[:name]]
        if !options[:id]
          host = @api.resource(:hosts).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Host '#{options[:name]}' not found" if !host || host.empty?
          options[:id] = host[0]['id']
          @query_hosts[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @query_hosts.key(options[:id])
        if !options[:name]
          host = @api.resource(:hosts).call(:show, {'id' => options[:id]})
          raise "Host 'id=#{options[:id]}' not found" if !host || host.empty?
          options[:name] = host['name']
          @query_hosts[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_hostgroup(options = {})
      @query_hostgroups ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @query_hostgroups[options[:name]]
        if !options[:id]
          hostgroup = @api.resource(:hostgroups).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Host Group '#{options[:name]}' not found" if !hostgroup || hostgroup.empty?
          options[:id] = hostgroup[0]['id']
          @query_hostgroups[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @query_hostgroups.key(options[:id])
        if !options[:name]
          hostgroup = @api.resource(:hostgroups).call(:show, {'id' => options[:id]})
          raise "Host Group 'id=#{options[:id]}' not found" if !hostgroup || hostgroup.empty?
          options[:name] = hostgroup['name']
          @query_hostgroups[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_provisioning_template(options = {})
      @query_config_templates ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @query_config_templates[options[:name]]
        if !options[:id]
          config_template = @api.resource(:config_templates).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Provisioning template '#{options[:name]}' not found" if !config_template || config_template.empty?
          options[:id] = config_template[0]['id']
          @query_config_templates[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @query_config_templates.key(options[:id])
        if !options[:name]
          config_template = @api.resource(:config_templates).call(:show, {'id' => options[:id]})
          raise "Provisioning template 'id=#{options[:id]}' not found" if !config_template || config_template.empty?
          options[:name] = config_template['name']
          @query_config_templates[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_smart_proxy(options = {})
      @query_smart_proxies ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @query_smart_proxies[options[:name]]
        if !options[:id]
          smart_proxy = @api.resource(:smart_proxies).call(:index, {
                                              :per_page => 999999,
                                              'search' => "name=\"#{options[:name]}\""
                                            })['results']
          raise "Smart Proxy '#{options[:name]}' not found" if !smart_proxy || smart_proxy.empty?
          options[:id] = smart_proxy[0]['id']
          @query_smart_proxies[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @query_smart_proxies.key(options[:id])
        if !options[:name]
          smart_proxy = @api.resource(:smart_proxies).call(:show, {'id' => options[:id]})
          raise "Smart Proxy 'id=#{options[:id]}' not found" if !smart_proxy || smart_proxy.empty?
          options[:name] = smart_proxy['name']
          @query_smart_proxies[options[:name]] = options[:id]
        end
        result = options[:name]
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
              'organization_id' => foreman_organization(:name => organization)
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

    def katello_contentviewversion(organization, name, version='latest')
      @contentviewversions ||= {}
      @contentviewversions[organization] ||= {}
      versionname = "#{version}|#{name}"

      return nil if name.nil? || name.empty?
      id = @contentviewversions[organization][versionname]
      if !id
        contentview_id = katello_contentview(organization, :name => name)
        contentviewversions = @api.resource(:content_view_versions).call(:index, {
                                  :per_page => 999999,
                                  'content_view_id' => contentview_id
                              })['results'].sort { |a, b| a['created_at'] <=> b['created_at'] }
        if version == 'latest'
          @contentviewversions[organization][versionname] = contentviewversions[-1]['id']
        else
          contentviewversions.each do |contentviewversion|
            if contentviewversion['version'] == version.to_f
              @contentviewversions[organization][versionname] = contentviewversion['id']
            end
          end
        end
        id = @contentviewversions[organization][versionname]
        raise "Content view version '#{name}' with version '#{version}' not found" if !id
      end

      id
    end

    def katello_repository(organization, options = {})
      @repositories ||= {}
      @repositories[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @repositories[organization][options[:name]]
        if !options[:id]
          @api.resource(:repositories).call(:index, {
              :per_page => 999999,
              'organization_id' => foreman_organization(:name => organization)
          })['results'].each do |repository|
            @repositories[organization][repository['name']] = repository['id']
          end
          options[:id] = @repositories[organization][options[:name]]
          raise "Repository '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @repositories.key(options[:id])
        if !options[:name]
          repository = @api.resource(:repositories).call(:show, {'id' => options[:id]})
          raise "Puppet repository '#{options[:name]}' not found" if !repository || repository.empty?
          options[:name] = repository['name']
          @repositoriesr[options[:name]] = options[:id]
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
                    'search' => search_string('host-collections',options[:name])
                  })['results'].each do |hostcollection|
            @hostcollections[organization][hostcollection['name']] = hostcollection['id'] if hostcollection
          end
          options[:id] = @hostcollections[organization][options[:name]]
          raise "Host collection '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @hostcollections.key(options[:id])
        if !options[:name]
          hostcollection = @api.resource(:host_collections).call(:show, {'id' => options[:id]})
          raise "Host collection '#{options[:name]}' not found" if !hostcollection || hostcollection.empty?
          options[:name] = hostcollection['name']
          @hostcollections[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def katello_product(organization, options = {})
      @products ||= {}
      @products[organization] ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @products[organization][options[:name]]
        if !options[:id]
          @api.resource(:products).call(:index,
                  {
                    :per_page => 999999,
                    'organization_id' => foreman_organization(:name => organization),
                    'search' => search_string('host-collections',options[:name])
                  })['results'].each do |product|
            @products[organization][product['name']] = product['id'] if product
          end
          options[:id] = @products[organization][options[:name]]
          raise "Host collection '#{options[:name]}' not found" if !options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @products.key(options[:id])
        if !options[:name]
          product = @api.resource(:host_collections).call(:show, {'id' => options[:id]})
          raise "Host collection '#{options[:name]}' not found" if !product || product.empty?
          options[:name] = product['name']
          @products[options[:name]] = options[:id]
        end
        result = options[:name]
      end

      result
    end

    def foreman_container(options = {})
      @containers ||= {}

      if options[:name]
        return nil if options[:name].nil? || options[:name].empty?
        options[:id] = @containers[options[:name]]
        if !options[:id]
          container = @api.resource(:containers).call(:index, {
                                                       :per_page => 999999,
                                                       'search' => "name=\"#{options[:name]}\""
                                                     })['results']
          raise "Container '#{options[:name]}' not found" if !container || container.empty?
          options[:id] = container[0]['id']
          @containers[options[:name]] = options[:id]
        end
        result = options[:id]
      else
        return nil if options[:id].nil?
        options[:name] = @containers.key(options[:id])
        if !options[:name]
          container = @api.resource(:containers).call(:show, {'id' => options[:id]})
          raise "Container 'id=#{options[:id]}' not found" if !container || container.empty?
          options[:name] = container['name']
          @containers[options[:name]] = options[:id]
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

    def export_column(object, name, field=nil)
      return '' unless object[name]
      values = CSV.generate do |column|
        column << object[name].collect do |fields|
          field.nil? ? yield(fields) : fields[field]
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
        @api.resource(:organizations).call(:update, {
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

        @api.resource(:locations).call(:update, {
            'id' => location_id,
            'location' => {
                "#{name}_ids" => associations[location]
            }
        })
      end if locations && !locations.empty?
    end

    def apipie_check_param(resource, action, name)
      method = @api.resource(pluralize(resource).to_sym).apidoc[:methods].detect do |api_method|
        api_method[:name] == action.to_s
      end
      return false unless method

      found = method[:params].detect do |param|
        param[:full_name] == name
      end
      if !found
        nested =  method[:params].detect do |param|
          param[:name] == resource.to_s
        end
        if nested
          found = nested[:params].detect do |param|
            param[:full_name] == name
          end
        end
      end
      found
    end

    def count(value)
      return 1 if value.nil? || value.empty?
      value.to_i
    end

    private

    def search_string(resource, name)
      operator = case resource
                 when "gpg-key", "sync-plan", "lifecycle-environment", "host-collections"
                   @server_status['version'] && @server_status['version'].match(/\A1\.6/) ? ':' : '='
                 else
                   ':'
                 end
      "name#{operator}\"#{name}\""
    end
  end
end
