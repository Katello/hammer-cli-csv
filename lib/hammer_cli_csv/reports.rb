# Copyright 2013-2014 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.


module HammerCLICsv
  class ReportsCommand < BaseCommand

    TIME = 'Time'
    APPLIED = 'Applied'
    RESTARTED = 'Restarted'
    FAILED = 'Failed'
    FAILED_RESTARTS = 'Failed Restarts'
    SKIPPED = 'Skipped'
    PENDING = 'Pending'
    METRICS = 'Metrics'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
        csv << [NAME, COUNT]
        @api.resource(:reports).call(:index, {'per_page' => 999999})['results'].each do |report|
          csv << [report['host_name'], 1, report['metrics'].to_json]
        end
      end

      HammerCLI::EX_OK
    end

    def import
      @existing_reports = {}
      @api.resource(:reports).call(:index, {'per_page' => 999999})['results'].each do |report|
        @existing_reports[report['name']] = report['id']
      end

      thread_import do |line|
        create_reports_from_csv(line)
      end
    end

    def create_reports_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)

        if !@existing_reports[name]
          print "Creating report '#{name}'..." if option_verbose?
          report = @api.resource(:reports).call(:create, {
                                          'host' => name,
                                          'reported_at' => line[TIME],
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
=begin
                                          'metrics' => {
                                            'time' => {
                                              'config_retrieval' => line[CONFIG_RETRIEVAL]
                                            },
                                            'resources' => {
                                              'applied' => 0,
                                              'failed' => 0,
                                              'failed_restarts' => 0,
                                              'out_of_sync' => 0,
                                              'restarted' => 0,
                                              'scheduled' => 1368,
                                              'skipped' => 1,
                                              'total' => 1450
                                            },
                                            'changes' => {
                                              'total' => 0
                                            }
                                          },
=end
          @existing_reports[name] = report['id']
        else
          print "Updating report '#{name}'..." if option_verbose?
          @api.resource(:reports).call(:update, {
                                 'id' => @existing_reports[name]
                               })
        end

        puts "done" if option_verbose?
      end
    end
  end

  HammerCLI::MainCommand.subcommand("csv:reports", "import / export reports", HammerCLICsv::ReportsCommand)
end
