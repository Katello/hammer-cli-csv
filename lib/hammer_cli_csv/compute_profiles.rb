# TODO: waiting for https://github.com/theforeman/foreman/pull/1326
module HammerCLICsv
  class CsvCommand
    class ComputeProfilesCommand < BaseCommand
      command_name 'compute-profiles'
      desc 'import or export compute profiles'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      DESCRIPTION = 'Description'
      PROVIDER = 'Provider'
      URL = 'URL'

      def export
        csv << [NAME, ORGANIZATIONS, LOCATIONS, DESCRIPTION, PROVIDER, URL]
        @api.resource(:compute_profiles).call(:index, {
            :per_page => 999999,
            :search => option_search
        })['results'].each do |compute_profile|
          puts compute_profile
          compute_profile = @api.resource(:compute_profiles).call(:show, {'id' => compute_profile['id']})
          name = compute_profile['name']
          organizations = export_column(compute_profile, 'organizations', 'name')
          locations = export_column(compute_profile, 'locations', 'name')
          description = compute_profile['description']
          provider = compute_profile['provider']
          url = compute_profile['url']
          csv << [name, organizations, locations, description, provider, url]
        end
      end

      def import
        @existing = {}
        @api.resource(:compute_profiles).call(:index, {:per_page => 999999})['results'].each do |compute_profile|
          @existing[compute_profile['name']] = compute_profile['id'] if compute_profile
        end

        thread_import do |line|
          create_compute_profiles_from_csv(line)
        end
      end

      def create_compute_profiles_from_csv(line)
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating compute profile '#{name}'..." if option_verbose?
            id = @api.resource(:compute_profiles).call(:create, {
                'compute_profile' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['id']
          else
            print "Updating compute profile '#{name}'..." if option_verbose?
            id = @api.resource(:compute_profiles).call(:update, {
                'id' => @existing[name],
                'compute_profile' => {
                    'name' => name,
                    'url' => line[URL]
                }
            })['compute_profile']['id']
          end

          # Update associated profiles
          associate_organizations(id, line[ORGANIZATIONS], 'compute_profile')
          associate_locations(id, line[LOCATIONS], 'compute_profile')

          print "done\n" if option_verbose?
        end
      end
    end
  end
end
