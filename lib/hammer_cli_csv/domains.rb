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
#
# -= Domains CSV =-
#
# Columns
#   Name
#     - Domain name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class DomainsCommand < BaseCommand

    FULLNAME = 'Full Name'
    ORGANIZATIONS = 'Organizations'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, FULLNAME]
        @f_domain_api.index({:per_page => 999999})[0]['results'].each do |domain|
          puts domain
          name = domain['name']
          count = 1
          fullname = domain['fullname']
          csv << [name, count, fullname]
        end
      end
    end

    def import
      @existing = {}
      @f_domain_api.index({:per_page => 999999})[0]['results'].each do |domain|
        @existing[domain['name']] = domain['id'] if domain
      end

      thread_import do |line|
        create_domains_from_csv(line)
      end
    end

    def create_domains_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        if !@existing.include? name
          print "Creating domain '#{name}'..." if option_verbose?
          domain_id = @f_domain_api.create({
                                             'domain' => {
                                               'name' => name
                                             }
                                           })[0]['domain']['id']
        else
          print "Updating domain '#{name}'..." if option_verbose?
          domain_id = @f_domain_api.update({
                                             'id' => @existing[name],
                                             'domain' => {
                                               'name' => name
                                             }
                                           })[0]['domain']['id']
        end

        CSV.parse_line(line[ORGANIZATIONS]).each do |organization_label|
          @k_organization_api.update({
                                       'id' => organization_label,
                                       'domain_ids' => [domain_id]
                                     })
        end

        print "done\n" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:domains", "ping the katello server", HammerCLICsv::DomainsCommand)
end
