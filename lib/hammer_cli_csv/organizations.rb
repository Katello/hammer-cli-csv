module HammerCLICsv
  class CsvCommand
    class OrganizationsCommand < BaseCommand
      command_name 'organizations'
      desc         'import or export organizations'

      LABEL = 'Label'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, LABEL, DESCRIPTION]

          if @server_status['release'] == 'Headpin'
            @headpin.get(:organizations).each do |organization|
              next if option_organization && organization['name'] != option_organization
              csv << [organization['name'], 1, organization['label'], organization['description']]
            end
          else
            @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
              next if option_organization && organization['name'] != option_organization
              csv << [organization['name'], 1, organization['label'], organization['description']]
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          @existing[organization['name']] = organization['id'] if organization
        end

        thread_import do |line|
          create_organizations_from_csv(line)
        end
      end

      def create_organizations_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          label = namify(line[LABEL], number)
          if !@existing.include? name
            print "Creating organization '#{name}'... " if option_verbose?
            @api.resource(:organizations).call(:create, {
                'name' => name,
                'organization' => {
                    'name' => name,
                    'label' => label,
                    'description' => line[DESCRIPTION]
                }
            })
          else
            print "Updating organization '#{name}'... " if option_verbose?
            @api.resource(:organizations).call(:update, {
                'id' => foreman_organization(:name => name),
                'organization' => {
                    'id' => foreman_organization(:name => name),
                    'description' => line[DESCRIPTION]
                }
            })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
