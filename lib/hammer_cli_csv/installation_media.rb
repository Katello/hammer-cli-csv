module HammerCLICsv
  class CsvCommand
    class InstallationMediaCommand < BaseCommand
      command_name 'installation-media'
      desc         'import or export media'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      PATH = 'Path'
      OSFAMILY = 'OS Family'
      OPERATING_SYSTEMS = 'Operating Systems'

      def export(csv)
        csv << [NAME, ORGANIZATIONS, LOCATIONS, PATH, OSFAMILY, OPERATING_SYSTEMS]
        @api.resource(:media).call(:index, {:per_page => 999999})['results'].each do |medium|
          medium = @api.resource(:media).call(:show, :id => medium['id'])
          name = medium['name']
          organizations = export_column(medium, 'organizations', 'name')
          locations = export_column(medium, 'locations', 'name')
          count = 1
          path = medium['path']
          os_family = medium['os_family']
          operating_systems = export_column(medium, 'operatingsystems', 'title')
          csv << [name, organizations, locations, path, os_family, operating_systems]
        end
      end

      def import
        @existing = {}
        @api.resource(:media).call(:index, {:per_page => 999999})['results'].each do |medium|
          @existing[medium['name']] = medium['id'] if medium
        end

        thread_import do |line|
          create_from_csv(line)
        end
      end

      def create_from_csv(line)
        params = {
          'medium' => {
            'organization_ids' => collect_column(line[ORGANIZATIONS]) do |organization|
              foreman_organization(:name => organization)
            end,
            'location_ids' => collect_column(line[LOCATIONS]) do |location|
              foreman_location(:name => location)
            end,
            'path' => line[PATH],
            'os_family' => line[OSFAMILY],
            'operatingsystem_ids' => collect_column(line[OPERATING_SYSTEMS]) do |os|
              foreman_operatingsystem(:name => os)
            end
          }
        }

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          params['medium']['name'] = name

          if !@existing.include? name
            print _("Creating installation medium '%{name}'... ") % {:name => name} if option_verbose?
            medium = @api.resource(:media).call(:create, params)
            @existing[name] = medium['id']
          else
            print _("Updating installation medium '%{name}'... ") % {:name => name} if option_verbose?
            params['id'] = @existing[name]
            medium = @api.resource(:media).call(:update, params)
          end
          puts _('done') if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
