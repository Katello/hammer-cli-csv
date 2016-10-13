module HammerCLICsv
  class CsvCommand
    class ArchitecturesCommand < BaseCommand
      command_name 'architectures'
      desc         'import or export architectures'

      OPERATINGSYSTEMS = 'Operating Systems'

      def export(csv)
        csv << [NAME, OPERATINGSYSTEMS]
        @api.resource(:architectures).call(:index, {
            :per_page => 999999,
            :search => option_search
        })['results'].each do |architecture|
          architecture = @api.resource(:architectures).call(:show, {:id => architecture['id']})
          name = architecture['name']
          operatingsystems = export_column(architecture, 'operatingsystems', 'title')
          csv << [name, operatingsystems]
        end
      end

      def import
        @existing = {}
        @api.resource(:architectures).call(:index, {:per_page => 999999})['results'].each do |architecture|
          @existing[architecture['name']] = architecture['id'] if architecture
        end

        thread_import do |line|
          create_architectures_from_csv(line)
        end
      end

      def create_architectures_from_csv(line)
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          architecture_id = @existing[name]
          operatingsystem_ids = CSV.parse_line(line[OPERATINGSYSTEMS]).collect do |operatingsystem_name|
            foreman_operatingsystem(:name => operatingsystem_name)
          end
          if !architecture_id
            print "Creating architecture '#{name}'..." if option_verbose?
            architecture_id = @api.resource(:architectures).call(:create, {
                               'architecture' => {
                                 'name' => name,
                                 'operatingsystem_ids' => operatingsystem_ids
                               }
                             })
          else
            print "Updating architecture '#{name}'..." if option_verbose?
            @api.resource(:architectures).call(:update, {
                               'id' => architecture_id,
                               'architecture' => {
                                 'name' => name,
                                 'operatingsystem_ids' => operatingsystem_ids
                               }
                             })
          end
          print "done\n" if option_verbose?
        end
      end
    end
  end
end
