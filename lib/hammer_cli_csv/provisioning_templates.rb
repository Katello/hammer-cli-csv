module HammerCLICsv
  class CsvCommand
    class ProvisioningTemplatesCommand < BaseCommand
      command_name 'provisioning-templates'
      desc         'import or export provisioning templates'

      option %w(--include-locked), :flag, 'Include locked templates (will fail if re-imported)',
                                   :attribute_name => :option_include_locked

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      OPERATINGSYSTEMS = 'Operating Systems'
      ASSOCIATIONS = 'Host Group / Puppet Environment Combinations'
      KIND = 'Kind'
      TEMPLATE = 'Template'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, ORGANIZATIONS, LOCATIONS, OPERATINGSYSTEMS, ASSOCIATIONS, KIND, TEMPLATE]
          params = {
              :per_page => 999999
          }
          params['search'] =  "organization = \"#{option_organization}\"" if option_organization
          @api.resource(:config_templates).call(:index, params)['results'].each do |template_id|
            template = @api.resource(:config_templates).call(:show, {:id => template_id['id']})
            next if template['locked'] && !option_include_locked?
            name = template['name']
            kind = template['snippet'] ? 'snippet' : template['template_kind_name']
            organizations = export_column(template, 'organizations', 'name')
            locations = export_column(template, 'locations', 'name')
            operatingsystems = export_column(template, 'operatingsystems', 'fullname')
            # TODO: puppet environments for content views are not present in api
            # http://projects.theforeman.org/issues/10293
            associations = export_associations(template)
            unless name == 'Boot disk iPXE - generic host' || name == 'Boot disk iPXE - host'
              csv << [name, organizations, locations, operatingsystems, associations, kind, template['template']]
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:config_templates).call(:index, {
            :per_page => 999999
        })['results'].each do |template|
          @existing[template['name']] = template['id'] if template
        end

        thread_import do |line|
          create_templates_from_csv(line)
        end
      end

      def create_templates_from_csv(line)
        organizations = collect_column(line[ORGANIZATIONS]) do |organization|
          foreman_organization(:name => organization)
        end
        if option_organization
          org_id = foreman_organization(:name => option_organization)
          return if org_id.nil? || !organizations.include?(org_id)
          organizations = [org_id]
        end
        locations = collect_column(line[LOCATIONS]) do |location|
          foreman_location(:name => location)
        end
        operatingsystems = collect_column(line[OPERATINGSYSTEMS]) do |operatingsystem|
          foreman_operatingsystem(:name => operatingsystem)
        end

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print _("Creating provisioning template '%{name}'...") % {:name => name } if option_verbose?
            template_id = @api.resource(:config_templates).call(:create, {
                'config_template' => {
                  'name' => name,
                  'snippet' => line[KIND] == 'snippet',
                  'template_kind_id' => line[KIND] == 'snippet' ? nil : foreman_template_kind(:name => line[KIND]),
                  'operatingsystem_ids' => operatingsystems,
                  'location_ids' => locations,
                  'template' => line[TEMPLATE]
                }
            })['id']
          else
            print _("Updating provisioning template '%{name}'...") % {:name => name} if option_verbose?
            template_id = @api.resource(:config_templates).call(:update, {
                'id' => @existing[name],
                'config_template' => {
                  'name' => name,
                  'snippet' => line[KIND] == 'snippet',
                  'template_kind_id' => line[KIND] == 'snippet' ? nil : foreman_template_kind(:name => line[KIND]),
                  'operatingsystem_ids' => operatingsystems,
                  'location_ids' => locations,
                  'template' => line[TEMPLATE]
                }
            })['id']
          end
          @existing[name] = template_id

          # Update associated resources
          @template_organizations ||= {}
          organizations.each do |organization_id|
            if @template_organizations[organization_id].nil?
              @template_organizations[organization_id] = @api.resource(:organizations).call(:show, {
                  'id' => organization_id
              })['config_templates'].collect do |template|
                template['id']
              end
            end
            if !@template_organizations[organization_id].include? template_id
              @template_organizations[organization_id] << template_id
              @api.resource(:organizations).call(:update, {
                  'id' => organization_id,
                  'organization' => {
                      'config_template_ids' => @template_organizations[organization_id]
                  }
              })
            end
          end
          @template_locations ||= {}
          locations.each do |location_id|
            if @template_locations[location_id].nil?
              @template_locations[location_id] = @api.resource(:locations).call(:show, {
                  'id' => location_id
              })['config_templates'].collect do |template|
                template['id']
              end
            end
            if !@template_locations[location_id].include? template_id
              @template_locations[location_id] += [template_id]
              @api.resource(:locations).call(:update, {
                  'id' => location_id,
                  'location' => {
                      'config_template_ids' => @template_locations[location_id]
                  }
              })
            end
          end

          puts _('done') if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line[NAME]}"
      end

      def export_associations(template)
        return '' unless template['template_combinations']
        values = CSV.generate do |column|
          column << template['template_combinations'].collect do |combo|
            "#{combo['hostgroup_name']}|#{combo['environment_name']}"
          end
        end
        values.delete!("\n")
      end
    end
  end
end
