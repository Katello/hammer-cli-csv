module HammerCLICsv
  class CsvCommand
    class OperatingSystemsCommand < BaseCommand
      command_name 'operating-systems'
      desc         'import or export operating systems'

      FAMILY = 'Family'
      DESCRIPTION = 'Description'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, DESCRIPTION, FAMILY]
          @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem|
            name = build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])
            count = 1
            description = operatingsystem['description']
            family = operatingsystem['family']
            csv << [name, count, description, family]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:operatingsystems).call(:index, {:per_page => 999999})['results'].each do |operatingsystem|
          @existing[build_os_name(operatingsystem['name'], operatingsystem['major'], operatingsystem['minor'])] = operatingsystem['id'] if operatingsystem
        end

        thread_import do |line|
          create_operatingsystems_from_csv(line)
        end
      end

      def create_operatingsystems_from_csv(line)
        params =  {
          'operatingsystem' => {
            'family' => line[FAMILY],
            'description' => line[DESCRIPTION]
          }
        }
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          (osname, major, minor) = split_os_name(name)
          params['operatingsystem']['name'] = osname
          params['operatingsystem']['major'] = major
          params['operatingsystem']['minor'] = minor
          if !@existing.include? name
            print "Creating operating system '#{name}'..." if option_verbose?
            @api.resource(:operatingsystems).call(:create, params)
          else
            print "Updating operating system '#{name}'..." if option_verbose?
            params['id'] = @existing[name]
            @api.resource(:operatingsystems).call(:update, params)
          end
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
