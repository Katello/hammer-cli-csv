# Copyright (c) 2013 Red Hat
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
        host = @f_host_api.index({:per_page => 1})[0]['results'][0]
        headers += @f_puppetfacts_api.index({'host_id' => host['name'], 'per_page' => 999999})[0]['results'][host['name']].keys
        csv << headers

        @f_host_api.index({:per_page => 999999})[0]['results'].each do |host|
          line = [host['name'], 1]
          facts = @f_puppetfacts_api.index({'host_id' => host['name'], 'per_page' => 999999})[0][host['name']]
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

        @f_host_api.facts({
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
