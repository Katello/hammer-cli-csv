module HammerCLICsv
  class CsvCommand
    class SettingsCommand < BaseCommand
      command_name 'settings'
      desc         'import or export settings'

      VALUE = 'Value'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb') do |csv|
          csv << [NAME, COUNT, VALUE]
          @api.resource(:settings).call(:index, {'per_page' => 999999})['results'].each do |setting|
            csv << [setting['name'], 1, setting['value']]
          end
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_settings_from_csv(line)
        end
      end

      def create_settings_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          params =  { 'id' => get_setting_id(name),
                      'setting' => {
                        'value' => line[VALUE]
                      }
                    }
          print "Updating setting '#{name}'..." if option_verbose?
          @api.resource(:settings).call(:update, params)
        end
        print "done\n" if option_verbose?
      end

      private

      def get_setting_id(name)
        results = @api.resource(:settings).call(:index, { :search => "name=\"#{name}\"" })['results']
        raise "Setting '#{name}' not found" if !results || results.empty?
        results[0]['id']
      end
    end
  end
end
