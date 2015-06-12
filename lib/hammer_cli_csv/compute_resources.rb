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

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, DESCRIPTION, PROVIDER, URL]
          @api.resource(:compute_resources).call(:index, {:per_page => 999999})['results'].each do |compute_resource|
            compute_resource = @api.resource(:compute_resources).call(:show, {'id' => compute_resource['id']})

            name = compute_resource['name']
            count = 1
            organizations = export_column(compute_resource, 'organizations', 'name')
            locations = export_column(compute_resource, 'locations', 'name')
            description = compute_resource['description']
            provider = compute_resource['provider']
            url = compute_resource['url']
            csv << [name, count, organizations, locations, description, provider, url]
          end
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
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating compute resource '#{name}'..." if option_verbose?
            id = @api.resource(:compute_resources).call(:create, {
                'compute_resource' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['id']
          else
            print "Updating compute resource '#{name}'..." if option_verbose?
            id = @api.resource(:compute_resources).call(:update, {
                'id' => @existing[name],
                'compute_resource' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['compute_resource']['id']
          end

          # Update associated resources
          associate_organizations(id, line[ORGANIZATIONS], 'compute_resource')
          associate_locations(id, line[LOCATIONS], 'compute_resource')

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
