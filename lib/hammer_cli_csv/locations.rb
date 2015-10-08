module HammerCLICsv
  class CsvCommand
    class LocationsCommand < BaseCommand
      command_name 'locations'
      desc         'import or export locations'

      PARENT = 'Parent Location'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, PARENT]
          @api.resource(:locations).call(:index, {:per_page => 999999})['results'].each do |location|
            csv << [location['name'], '']
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:locations).call(:index, {:per_page => 999999})['results'].each do |location|
          @existing[location['name']] = location['id'] if location
        end

        thread_import do |line|
          create_locations_from_csv(line)
        end
      end

      def create_locations_from_csv(line)
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          location_id = @existing[name]
          if !location_id
            print "Creating location '#{name}'... " if option_verbose?
            @api.resource(:locations).call(:create, {
                                             'location' => {
                                               'name' => name,
                                               'parent_id' => foreman_location(:name => line[PARENT])
                                             }
                                           })
          else
            print "Updating location '#{name}'... " if option_verbose?
            @api.resource(:locations).call(:update, {
                                             'id' => location_id,
                                             'location' => {
                                               'parent_id' => foreman_location(:name => line[PARENT])
                                             }
                                           })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
