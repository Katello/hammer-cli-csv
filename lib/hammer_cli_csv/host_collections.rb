module HammerCLICsv
  class CsvCommand
    class HostCollectionsCommand < BaseCommand
      command_name 'host-collections'
      desc         'import or export host collections'

      ORGANIZATION = 'Organization'
      LIMIT = 'Limit'
      DESCRIPTION = 'Description'

      def export(csv)
        csv << [NAME, ORGANIZATION, LIMIT, DESCRIPTION]
        @api.resource(:organizations).call(:index, {'per_page' => 999999})['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization
          @api.resource(:host_collections).call(:index, {
              'organization_id' => organization['id'],
              'search' => option_search
          })['results'].each do |hostcollection|
            limit = hostcollection['unlimited_content_hosts'] ? 'Unlimited' : hostcollection['max_content_hosts']
            csv << [hostcollection['name'], organization['name'],
                    limit,
                    hostcollection['description']]
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_hostcollections_from_csv(line)
        end
      end

      def create_hostcollections_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        if !@existing[line[ORGANIZATION]]
          @existing[line[ORGANIZATION]] = {}
          @api.resource(:host_collections).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION])
          })['results'].each do |hostcollection|
            @existing[line[ORGANIZATION]][hostcollection['name']] = hostcollection['id']
          end
        end

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          params =  {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'name' => name,
                      'unlimited_content_hosts' => (line[LIMIT] == 'Unlimited') ? true : false,
                      'max_content_hosts' => (line[LIMIT] == 'Unlimited') ? nil : line[LIMIT].to_i,
                      'description' => line[DESCRIPTION]
                    }
          if !@existing[line[ORGANIZATION]].include? name
            print "Creating host collection '#{name}'..." if option_verbose?
            @api.resource(:host_collections).call(:create, params)
          else
            print "Updating host collection '#{name}'..." if option_verbose?
            params['id'] = @existing[line[ORGANIZATION]][name]
            @api.resource(:host_collections).call(:update, params)
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
