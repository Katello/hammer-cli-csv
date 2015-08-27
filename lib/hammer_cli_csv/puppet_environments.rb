module HammerCLICsv
  class CsvCommand
    class PuppetEnvironmentsCommand < BaseCommand
      command_name 'puppet-environments'
      desc         'import or export puppet environments'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS]
          @api.resource(:environments).call(:index, {:per_page => 999999})['results'].each do |environment|
            environment = @api.resource(:environments).call(:show, {:id => environment['id']})
            name = environment['name']
            count = 1
            organizations = export_column(environment, 'organizations', 'name')
            locations = export_column(environment, 'locations', 'name')
            csv << [name, count, organizations, locations]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:environments).call(:index, {:per_page => 999999})['results'].each do |environment|
          @existing[environment['name']] = environment['id'] if environment
        end

        thread_import do |line|
          create_environments_from_csv(line)
        end
      end

      def create_environments_from_csv(line)
        organizations = collect_column(line[ORGANIZATIONS]) do |organization|
          foreman_organization(:name => organization)
        end
        locations = collect_column(line[LOCATIONS]) do |location|
          foreman_location(:name => location)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating environment '#{name}'..." if option_verbose?
            id = @api.resource(:environments).call(:create, {
                                             'environment' => {
                                               'name' => name,
                                               'organization_ids' => organizations
                                             }
                                           })['id']
          else
            print "Updating environment '#{name}'..." if option_verbose?

            environment = @api.resource(:environments).call(:show, {'id' => @existing[name]})
            environment['organizations'].collect do |organization|
              organizations << organization['id']
            end
            organizations.uniq!
            environment['locations'].collect do |location|
              locations << location['id']
            end
            locations.uniq!

            @api.resource(:environments).call(:update, {
                                         'id' => @existing[name],
                                         'environment' => {
                                           'name' => name,
                                           'organization_ids' => organizations,
                                           'location_ids' => locations
                                         }
                                       })
          end

          puts "done" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
