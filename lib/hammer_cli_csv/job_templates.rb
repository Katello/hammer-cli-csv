module HammerCLICsv
  class CsvCommand
    class JobTemplatesCommand < BaseCommand
      command_name 'job-templates'
      desc         'import or export job templates'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      DESCRIPTION = 'Description'
      JOB = 'Job Category'
      PROVIDER = 'Provider'
      SNIPPET = 'Snippet'
      TEMPLATE = 'Template'
      INPUT_NAME = 'Input:Name'
      INPUT_DESCRIPTION = 'Input:Description'
      INPUT_REQUIRED = 'Input:Required'
      INPUT_TYPE = 'Input:Type'
      INPUT_PARAMETERS = 'Input:Parameters'

      def export(csv)
        csv << [NAME, ORGANIZATIONS, LOCATIONS, DESCRIPTION, JOB, PROVIDER, SNIPPET, TEMPLATE,
                INPUT_NAME, INPUT_DESCRIPTION, INPUT_REQUIRED, INPUT_TYPE, INPUT_PARAMETERS]
        @api.resource(:job_templates).call(:index, {
            :per_page => 999999
        })['results'].each do |template_id|
          template = @api.resource(:job_templates).call(:show, {:id => template_id['id']})
          next if template['locked']
          next unless option_organization.nil? || template['organizations'].detect { |org| org['name'] == option_organization }
          name = template['name']
          description = template['description_format']
          job = template['job_category']
          snippet = template['snippet'] ? 'Yes' : 'No'
          provider = template['provider_type']
          organizations = export_column(template, 'organizations', 'name')
          locations = export_column(template, 'locations', 'name')
          csv << [name, organizations, locations, description, job, provider, snippet, template['template']]

          template_columns = [name] + Array.new(7)
          @api.resource(:template_inputs).call(:index, {
              :template_id => template['id']
          })['results'].each  do|input|
            input_field = nil
            input_options = nil
            case input['input_type']
            when /user/
              input_name = export_column(input, 'options') do |value|
                value
              end
            when /fact/
              input_name = input['fact_name']
            when /variable/
              input_name = input['variable_name']
            when /puppet_parameter/
              input_name = "#{input['puppet_class_name']}|#{input['puppet_parameter_name']}"
            else
              raise _("Unknown job template input type '%{type}'") % {:type => input['input_type']}
            end
            required = input['required'] ? 'Yes' : 'No'
            csv << template_columns + [input['name'], input['description'], required, input['input_type'], input_name]
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
          if line[INPUT_NAME].nil? || line[INPUT_NAME].empty?
            create_template(line, number)
          else
            create_template_input(line, number)
          end

          # ????
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

        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line[NAME]}"
      end

      def create_template(line, number)
        name = namify(line[NAME], number)
        job_category = namify(line[JOB], number)
        options = {
              'job_template' => {
                'name' => name,
                'description_format' => line[DESCRIPTION],
                'job_category' => job_category,
                'snippet' => line[SNIPPET] == 'Yes' ? true : false,
                'provider_type' => line[PROVIDER],
                #'organization_ids' => organizations,
                #'location_ids' => locations,
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
        puts _('done') if option_verbose?
      end

      def create_template_input(line, number)
        name = namify(line[NAME], number)
        template_id = @existing[name]
        raise "Job template '#{name}' must exist before setting inputs" unless template_id

        options = {
          'template_id' => template_id,
          'template_input' => {
            'name' => line[INPUT_NAME],
            'description' => line[INPUT_DESCRIPTION],
            'input_type' => line[INPUT_TYPE],
            'required' => line[INPUT_REQUIRED] == 'Yes' ? true : false
          }
        }
        case line[INPUT_TYPE]
        when /user/
          options['template_input']['options'] = line[INPUT_PARAMETERS]
        when /fact/
          options['template_input']['fact_name'] = line[INPUT_PARAMETERS]
        when /variable/
          options['template_input']['variable_name'] = line[INPUT_PARAMETERS]
        when /puppet_parameter/
          options['template_input']['puppet_class_name'], options['template_input']['puppet_parameter_name'] = line[INPUT_PARAMETERS].split('|')
        else
          raise _("Unknown job template input type '%{type}'") % {:type => line[INPUT_TYPE]}
        end

        template_input = @api.resource(:template_inputs).call(:index, {
            :template_id => template_id,
            :search => "name = \"#{line[INPUT_NAME]}\""
        })['results']
        if template_input.empty?
          print _("Creating job template input '%{input_name}' on '%{name}'...") % {:input_name => line[INPUT_NAME], :name => name}
          @api.resource(:template_inputs).call(:create, options)
        else
          print _("Updating job template input '%{input_name}' on '%{name}'...") % {:input_name => line[INPUT_NAME], :name => name}
          options['id'] = template_input[0]['id']
          @api.resource(:template_inputs).call(:update, options)
        end
        puts _('done') if option_verbose?
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
