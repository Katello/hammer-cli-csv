module HammerCLICsv
  class CsvCommand
    class PartitionTablesCommand < BaseCommand
      command_name 'partition-tables'
      desc         'import or export partition tables'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      OSFAMILY = 'OS Family'
      OPERATINGSYSTEMS = 'Operating Systems'
      LAYOUT = 'Layout'

      def export
        # TODO: partition-tables do not return their organizations or locations
        # http://projects.theforeman.org/issues/11175
        organizations_map = {}
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          ptables = @api.resource(:ptables).call(:index, {'organization_id' => organization['id']})['results'].each do |ptable|
            organizations_map[ptable['name']] ||= []
            organizations_map[ptable['name']] << organization['name']
          end
        end
        locations_map = {}
        @api.resource(:locations).call(:index, {:per_page => 999999})['results'].each do |location|
          ptables = @api.resource(:ptables).call(:index, {'location_id' => location['id']})['results'].each do |ptable|
            locations_map[ptable['name']] ||= []
            locations_map[ptable['name']] << location['name']
          end
        end

        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, OSFAMILY, OPERATINGSYSTEMS, LAYOUT]
          @api.resource(:ptables).call(:index, {:per_page => 999999})['results'].each do |ptable|
            ptable = @api.resource(:ptables).call(:show, {'id' => ptable['id']})
            name = ptable['name']
            count = 1
            osfamily = ptable['os_family']
            layout = ptable['layout']
            operatingsystems = export_column(ptable, 'operatingsystems', 'title')

            organizations = CSV.generate do |column|
              column << organizations_map[name] if organizations_map[name]
            end
            organizations.delete!("\n")
            locations = CSV.generate do |column|
              column << locations_map[name] if locations_map[name]
            end
            locations.delete!("\n")

            csv << [name, count, organizations, locations, osfamily, operatingsystems, layout]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:ptables).call(:index, {:per_page => 999999})['results'].each do |ptable|
          @existing[ptable['name']] = ptable['id'] if ptable
        end

        thread_import do |line|
          create_ptables_from_csv(line)
        end
      end

      def create_ptables_from_csv(line)
        params = {
          'ptable' => {
            'os_family' => line[OSFAMILY],
            'layout' => line[LAYOUT]
          }
        }
        # Check for backwards compatibility
        if apipie_check_param(:ptable, :create, 'ptable[operatingsystem_ids]')
          operatingsystems = collect_column(line[OPERATINGSYSTEMS]) do |operatingsystem|
            foreman_operatingsystem(:name => operatingsystem)
          end
          params['ptable']['operatingsystem_ids'] = operatingsystems
        end
        if apipie_check_param(:ptable, :create, 'ptable[organization_ids]')
          organizations = collect_column(line[ORGANIZATIONS]) do |organization|
            foreman_organization(:name => organization)
          end
          params['ptable']['organization_ids'] = organizations
        end
        if apipie_check_param(:ptable, :create, 'ptable[location_ids]')
          locations = collect_column(line[LOCATIONS]) do |location|
            foreman_location(:name => location)
          end
          params['ptable']['location_ids'] = locations
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          params['ptable']['name'] = name
          if !@existing.include? name
            print "Creating partition-table '#{name}'... " if option_verbose?
            @api.resource(:ptables).call(:create, params)
          else
            print "Updating partition-table '#{name}'..." if option_verbose?
            params['id'] = @existing[name]
            @api.resource(:ptables).call(:update, params)
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
