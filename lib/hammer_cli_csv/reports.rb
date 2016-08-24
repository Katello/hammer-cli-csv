module HammerCLICsv
  class CsvCommand
    class ReportsCommand < BaseCommand
      command_name 'reports'
      desc         'import or export reports'

      TIME = 'Time'
      APPLIED = 'Applied'
      RESTARTED = 'Restarted'
      FAILED = 'Failed'
      FAILED_RESTARTS = 'Failed Restarts'
      SKIPPED = 'Skipped'
      PENDING = 'Pending'
      METRICS = 'Metrics'

      def export(csv)
        csv << [NAME]
        @api.resource(:reports).call(:index, {
            'per_page' => 999999
        })['results'].each do |report|
          csv << [report['host_name'], report['metrics'].to_json]
        end
      end

      def import
        @existing_reports = {}
        @api.resource(:reports).call(:index, {
            'per_page' => 999999
        })['results'].each do |report|
          @existing_reports[report['name']] = report['id']
        end

        thread_import do |line|
          create_reports_from_csv(line)
        end
      end

      def create_reports_from_csv(line)
        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)

          if !@existing_reports[name]
            print "Creating report '#{name}'..." if option_verbose?
            reported_at = line[TIME] || Time.now
            report = @api.resource(:reports).call(:create, {
                'host' => name,
                'reported_at' => reported_at,
                'status' => {
                    'applied' => line[APPLIED],
                    'restarted' => line[RESTARTED],
                    'failed' => line[FAILED],
                    'failed_restarts' => line[FAILED_RESTARTS],
                    'skipped' => line[SKIPPED],
                    'pending' => line[PENDING]
                },
                'metrics' => JSON.parse(line[METRICS]),
                'logs' => []
            })
            @existing_reports[name] = report['id']
          else
            print "Updating report '#{name}'..." if option_verbose?
            @api.resource(:reports).call(:update, {
                'id' => @existing_reports[name]
            })
          end

          puts 'done' if option_verbose?
        end
      end
    end
  end
end
