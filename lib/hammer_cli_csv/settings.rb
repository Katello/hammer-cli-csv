module HammerCLICsv
  class CsvCommand
    class SettingsCommand < BaseCommand
      command_name 'settings'
      desc         'import or export settings'

      VALUE = 'Value'

      def self.supported?
        true
      end

      def export(csv)
        csv << [NAME, VALUE]
        @api.resource(:settings).call(:index, {'per_page' => 999999})['results'].each do |setting|
          csv << [setting['name'], setting['value']]
        end
      end

      def import
        @existing = {}

        thread_import do |line|
          create_settings_from_csv(line)
        end
      end

      def create_settings_from_csv(line)
        count(line[COUNT]).times do |number|
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
