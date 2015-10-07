module HammerCLICsv
  class CsvCommand
    class ContainersCommand < BaseCommand
      command_name 'containers'
      desc         'import or export containers'

      REGISTRY = 'Registry'
      REPOSITORY = 'Repository:Tag'
      COMPUTERESOURCE = 'Compute Resource'
      ATTACH = 'Attach I/O'
      ENTRYPOINT = 'Entry Point'
      COMMAND = 'Command'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb') do |csv|
          csv << [NAME, COUNT, REGISTRY, REPOSITORY, COMPUTERESOURCE, ATTACH, ENTRYPOINT, COMMAND]
          @api.resource(:containers).call(:index, {'per_page' => 999999})['results'].each do |container|
            csv << [container['name'], 1,
                    container['registry_name'],
                    "#{container['repository_name']}:#{container['tag']}",
                    container['compute_resource_name'],
                    export_attach_types(container),
                    container['entrypoint'],
                    container['command']]
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_containers_from_csv(line)
        end
      end

      def create_containers_from_csv(line)
        # TODO: containers cannot be updated (no api)
        # line[COUNT].to_i.times do |number|
        #   name = namify(line[NAME], number)
        #   params =  { 'id' => foreman_container(:name => name),
        #               'container' => {
        #                 'name' => name,
        #                 'command' => line[COMMAND]
        #               }
        #             }
        #   print "Updating container '#{name}'..." if option_verbose?
        #   @api.resource(:containers).call(:update, params)
        # end
        # print "done\n" if option_verbose?
      end

      private

      def export_attach_types(container)
        types = []
        types << 'tty' if container['tty']
        types << 'stdin' if container['attach_stdin']
        types << 'stdout' if container['attach_stdout']
        types << 'stderr' if container['attach_stderr']
        types.join(',')
      end
    end
  end
end
