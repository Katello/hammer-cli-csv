module HammerCLICsv
  class CsvCommand
    class LifecycleEnvironmentsCommand < BaseCommand
      command_name 'lifecycle-environments'
      desc         'import or export lifecycle environments'

      ORGANIZATION = 'Organization'
      PRIORENVIRONMENT = 'Prior Environment'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, ORGANIZATION, PRIORENVIRONMENT, DESCRIPTION]
          @api.resource(:organizations).call(:index, {
              'per_page' => 999999
          })['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization

            @api.resource(:lifecycle_environments).call(:index, {
                'per_page' => 999999,
                'organization_id' => organization['id']
            })['results'].sort { |a, b| a['created_at'] <=> b['created_at'] }.each do |environment|
              if environment['name'] != 'Library'
                name = environment['name']
                prior = environment['prior']['name']
                description = environment['description']
                csv << [name, organization['name'], prior, description]
              end
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:organizations).call(:index, {
            'per_page' => 999999
        })['results'].each do |organization|
          @api.resource(:lifecycle_environments).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => organization['name'])
          })['results'].each do |environment|
            @existing[organization['name']] ||= {}
            @existing[organization['name']][environment['name']] = environment['id'] if environment
          end
        end

        thread_import do |line|
          create_environments_from_csv(line)
        end
      end

      def create_environments_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          prior = line[PRIORENVIRONMENT] == 'Library' ? 'Library' :
                                            namify(line[PRIORENVIRONMENT], number)
          raise "Organization '#{line[ORGANIZATION]}' does not exist" if !@existing.include? line[ORGANIZATION]
          if !@existing[line[ORGANIZATION]].include? name
            print "Creating environment '#{name}'..." if option_verbose?
            @api.resource(:lifecycle_environments).call(:create, {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => name,
                #'prior' => lifecycle_environment(line[ORGANIZATION], :name => prior),
                'prior_id' => lifecycle_environment(line[ORGANIZATION], :name => prior),
                'description' => line[DESCRIPTION]
            })
          else
            print "Updating environment '#{name}'..." if option_verbose?
            @api.resource(:lifecycle_environments).call(:update, {
                'id' => @existing[line[ORGANIZATION]][name],
                'description' => line[DESCRIPTION]
            })
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
