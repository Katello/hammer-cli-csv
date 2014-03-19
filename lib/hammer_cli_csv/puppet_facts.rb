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

#
# -= Puppet Facts CSV =-
#
# Columns
#   Name
#     - Host name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   <Fact Key names>
#     - May contain '%d' which will be replaced with current iteration number of Count
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class PuppetFactsCommand < BaseCommand

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        headers = [NAME, COUNT]
        # Extracted facts are always based upon the first host found, otherwise this would be an intensive
        # method to gather all the possible column names
        host = @api.resource(:hosts).call(:index, {:per_page => 1})['results'][0]
        headers += @api.resource(:puppetfactss).call(:index, {'host_id' => host['name'], 'per_page' => 999999})['results'][host['name']].keys
        csv << headers

        @api.resource(:hosts).call(:index, {:per_page => 999999})['results'].each do |host|
          line = [host['name'], 1]
          facts = @api.resource(:puppetfactss).call(:index, {'host_id' => host['name'], 'per_page' => 999999})[host['name']]
          facts ||= {}
          headers[2..-1].each do |fact_name|
            line << facts[fact_name] || ''
          end
          csv << line
        end
      end
    end

    def import
      @headers = nil

      thread_import(true) do |line|
        create_puppetfacts_from_csv(line)
      end
    end

    def create_puppetfacts_from_csv(line)
      if @headers.nil?
        @headers = line
        return
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        print "Updating puppetfacts '#{name}'..." if option_verbose?
        facts = line.to_hash
        facts.delete(NAME)
        facts.delete(COUNT)

        # Namify the values if the host name was namified
        if name != line[NAME]
          facts.each do |fact, value|
            facts[fact] = namify(value, number) unless value.nil? || value.empty?
          end
        end

        @api.resource(:hosts).call(:facts, {
                            'name' => name,
                            'facts' => facts
                          })
        print "done\n" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:puppetfacts", "ping the katello server", HammerCLICsv::PuppetFactsCommand)
end
