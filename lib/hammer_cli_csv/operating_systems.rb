module HammerCLICsv
  class CsvCommand
    class OperatingSystemsCommand < BaseCommand
      command_name 'operating-systems'
      desc         'import or export operating systems'

      FAMILY = 'Family'
      DESCRIPTION = 'Description'
      PASSWORD_HASH = 'Password Hash'
      PARTITION_TABLES = 'Partition Tables'
      ARCHITECTURES = 'Architectures'
      MEDIA = 'Media'
      PROVISIONING_TEMPLATES = 'Provisioning Templates'
      PARAMETERS = 'Parameters'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, DESCRIPTION, FAMILY, PASSWORD_HASH, PARTITION_TABLES, ARCHITECTURES, MEDIA,
                  PROVISIONING_TEMPLATES, PARAMETERS]
          @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem_id|
            operatingsystem = @api.resource(:operatingsystems).call(:show, {:id => operatingsystem_id['id']})
            name = build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])
            description = operatingsystem['description']
            family = operatingsystem['family']
            password_hash = operatingsystem['password_hash']
            partition_tables = export_column(operatingsystem, 'ptables', 'name')
            architectures = export_column(operatingsystem, 'architectures', 'name')
            media = export_column(operatingsystem, 'media', 'name')
            partition_tables = export_column(operatingsystem, 'ptables', 'name')
            parameters = export_column(operatingsystem, 'parameters') do |parameter|
              "#{parameter['name']}|#{parameter['value']}"
            end
            csv << [name, description, family, password_hash, partition_tables, architectures,
                    media, partition_tables, parameters]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem|
          @existing[build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])] = operatingsystem['id'] if operatingsystem
        end

        thread_import do |line|
          create_operatingsystems_from_csv(line)
        end
      end

      def create_operatingsystems_from_csv(line)
        params =  {
          'operatingsystem' => {
            'family' => line[FAMILY],
            'description' => line[DESCRIPTION],
            'password_hash' => line[PASSWORD_HASH]
          }
        }
        params['operatingsystem']['architecture_ids'] = collect_column(line[ARCHITECTURES]) do |name|
          foreman_architecture(:name => name)
        end
        # TODO: http://projects.theforeman.org/issues/12919
        #params['operatingsystem']['provisioning_template_ids'] = collect_column(line[PROVISIONING_TEMPLATES]) do |name|
        #  foreman_provisioning_template(:name => name)
        #end
        # TODO: http://projects.theforeman.org/issues/12920
        #params['operatingsystem']['os_parameters?'] = collect_column(line[PARAMETERS]) do |name_value|
        #  ????
        #end
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          (osname, major, minor) = split_os_name(name)
          params['operatingsystem']['name'] = osname
          params['operatingsystem']['major'] = major
          params['operatingsystem']['minor'] = minor
          if !@existing.include? name
            print "Creating operating system '#{name}'..." if option_verbose?
            @api.resource(:operatingsystems).call(:create, params)
          else
            print "Updating operating system '#{name}'..." if option_verbose?
            params['id'] = @existing[name]
            @api.resource(:operatingsystems).call(:update, params)
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
