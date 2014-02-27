# Copyright (c) 2013-2014 Red Hat
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

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
        @f_report_api.index({'per_page' => 999999})[0]['results'].each do |report|
          csv << [report['host_name'], 1, report['metrics'].to_json]
        end
      end

      HammerCLI::EX_OK
    end

    def import
      @existing_reports = {}
      @f_report_api.index({'per_page' => 999999})[0]['results'].each do |report|
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
          report = @f_report_api.create({
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
                                        })[0]
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
          @f_report_api.update({
                                 'id' => @existing_reports[name]
                               })
        end

        puts "done" if option_verbose?
      end
    end
  end

  HammerCLI::MainCommand.subcommand("csv:reports", "import / export reports", HammerCLICsv::ReportsCommand)
end
