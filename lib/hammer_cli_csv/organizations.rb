module HammerCLICsv
  class CsvCommand
    class OrganizationsCommand < BaseCommand
      command_name 'organizations'
      desc         'import or export organizations'

      LABEL = 'Label'
      DESCRIPTION = 'Description'

      def export(csv)
        csv << [NAME, LABEL, DESCRIPTION]

        if @server_status['release'] == 'Headpin'
          @headpin.get(:organizations).each do |organization|
            next if option_organization && organization['name'] != option_organization
            csv << [organization['name'], organization['label'], organization['description']]
          end
        else
          @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization
            csv << [organization['name'], organization['label'], organization['description']]
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
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          return if option_organization && name != option_organization
          label = namify(line[LABEL], number)
          organization_id = @existing[name]
          if organization_id.nil?
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
            organization = @api.resource(:organizations).call(:show, {'id' => organization_id})
            @api.resource(:organizations).call(:update, {
                'id' => organization_id,
                'organization' => {
                    'id' => organization_id,
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
