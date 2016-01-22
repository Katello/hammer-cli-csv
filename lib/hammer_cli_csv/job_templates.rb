module HammerCLICsv
  class CsvCommand
    class JobTemplatesCommand < BaseCommand
      command_name 'job-templates'
      desc         'import or export job templates'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      JOB = 'Job Category'
      PROVIDER = 'Provider'
      SNIPPET = 'Snippet'
      TEMPLATE = 'Template'
      INPUT_NAME = 'Input Name'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, ORGANIZATIONS, LOCATIONS, JOB, PROVIDER, SNIPPET, TEMPLATE, INPUT_NAME]
          @api.resource(:job_templates).call(:index, {
              :per_page => 999999
          })['results'].each do |template_id|
            template = @api.resource(:job_templates).call(:show, {:id => template_id['id']})
            next if template['locked']
            next unless option_organization.nil? || template['organizations'].detect { |org| org['name'] == option_organization }
            name = template['name']
            job = template['job_name']
            snippet = template['snippet'] ? 'Yes' : 'No'
            provider = template['provider_type']
            organizations = export_column(template, 'organizations', 'name')
            locations = export_column(template, 'locations', 'name')
            csv << [name, organizations, locations, job, provider, snippet, template['template']]

            template['template_inputs'].each do |input_id|
              input = @api.resource(:templates).call(:template_inputs, {:template_id => template['id'], :id => input_id['id']})
              x = input
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:job_templates).call(:index, {
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

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          job_name = namify(line[JOB], number)
          options = {
                'job_template' => {
                  'name' => name,
                  'job_name' => job_name,
                  'snippet' => line[SNIPPET] == 'Yes' ? true : false,
                  'provider_type' => line[PROVIDER],
                  'organization_ids' => organizations,
                  'location_ids' => locations,
                  'template' => line[TEMPLATE]
                }
          }
          template_id = @existing[name]
          if !template_id
            print _("Creating job template '%{name}'...") % {:name => name } if option_verbose?
            template_id = @api.resource(:job_templates).call(:create, options)['id']
            @existing[name] = template_id
          else
            print _("Updating job template '%{name}'...") % {:name => name} if option_verbose?
            options['id'] = template_id
            template_id = @api.resource(:job_templates).call(:update, options)['id']
          end

          # Update associated resources
          # @template_organizations ||= {}
          # organizations.each do |organization_id|
          #   if @template_organizations[organization_id].nil?
          #     @template_organizations[organization_id] = @api.resource(:organizations).call(:show, {
          #         'id' => organization_id
          #     })['config_templates'].collect do |template|
          #       template['id']
          #     end
          #   end
          #   if !@template_organizations[organization_id].include? template_id
          #     @template_organizations[organization_id] << template_id
          #     @api.resource(:organizations).call(:update, {
          #         'id' => organization_id,
          #         'organization' => {
          #             'config_template_ids' => @template_organizations[organization_id]
          #         }
          #     })
          #   end
          # end
          # @template_locations ||= {}
          # locations.each do |location_id|
          #   if @template_locations[location_id].nil?
          #     @template_locations[location_id] = @api.resource(:locations).call(:show, {
          #         'id' => location_id
          #     })['config_templates'].collect do |template|
          #       template['id']
          #     end
          #   end
          #   if !@template_locations[location_id].include? template_id
          #     @template_locations[location_id] += [template_id]
          #     @api.resource(:locations).call(:update, {
          #         'id' => location_id,
          #         'location' => {
          #             'config_template_ids' => @template_locations[location_id]
          #         }
          #     })
          #   end
          # end

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
