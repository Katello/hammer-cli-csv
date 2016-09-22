require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class CsvCommand
    class ComputeResourcesCommand < BaseCommand
      command_name 'compute-resources'
      desc 'import or export compute resources'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      DESCRIPTION = 'Description'
      PROVIDER = 'Provider'
      URL = 'URL'

      def export(csv)
        csv << [NAME, ORGANIZATIONS, LOCATIONS, DESCRIPTION, PROVIDER, URL]
        @api.resource(:compute_resources).call(:index, {:per_page => 999999})['results'].each do |compute_resource|
          compute_resource = @api.resource(:compute_resources).call(:show, {'id' => compute_resource['id']})

          name = compute_resource['name']
          organizations = export_column(compute_resource, 'organizations', 'name')
          locations = export_column(compute_resource, 'locations', 'name')
          description = compute_resource['description']
          provider = compute_resource['provider']
          url = compute_resource['url']
          csv << [name, organizations, locations, description, provider, url]
        end
      end

      def import
        @existing = {}
        @api.resource(:compute_resources).call(:index, {:per_page => 999999})['results'].each do |compute_resource|
          @existing[compute_resource['name']] = compute_resource['id'] if compute_resource
        end

        thread_import do |line|
          create_compute_resources_from_csv(line)
        end
      end

      def create_compute_resources_from_csv(line)
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          params = {
            'compute_resource' => {
              'name' => name,
              'url' => line[URL],
              'provider' => line[PROVIDER]
            }
          }
          if !@existing.include? name
            print _("Creating compute resource '%{name}'...") % {:name => name} if option_verbose?
            id = @api.resource(:compute_resources).call(:create, params)['id']
          else
            print _("Updating compute resource '%{name}'...") % {:name => name} if option_verbose?
            id = @existing[name]
            params['id'] = id
            @api.resource(:compute_resources).call(:update, params)
          end

          associate_organizations(id, line[ORGANIZATIONS], 'compute_resource')
          associate_locations(id, line[LOCATIONS], 'compute_resource')

          puts _("done") if option_verbose?
        end
      end
    end
  end
end
