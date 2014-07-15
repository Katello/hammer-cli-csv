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
  class CsvCommand
    class DomainsCommand < BaseCommand
      command_name 'domains'
      desc         'import or export domains'

      FULLNAME = 'Full Name'
      ORGANIZATIONS = 'Organizations'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, FULLNAME]
          @api.resource(:domains).call(:index, {:per_page => 999999})['results'].each do |domain|
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
        @api.resource(:domains).call(:index, {:per_page => 999999})['results'].each do |domain|
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
            domain_id = @api.resource(:domains).call(:create, {
                                                       'name' => name
                                                     })['id']
          else
            print "Updating domain '#{name}'..." if option_verbose?
            domain_id = @api.resource(:domains).call(:update, {
                                                       'id' => @existing[name],
                                                       'name' => name
                                                     })['id']
          end

          # Update associated resources
          domains ||= {}
          CSV.parse_line(line[ORGANIZATIONS]).each do |organization|
            organization_id = foreman_organization(:name => organization)
            if domains[organization].nil?
              domains[organization] = @api.resource(:organizations).call(:show, {'id' => organization_id})['domains'].collect do |domain|
                domain['id']
              end
            end
            domains[organization] += [domain_id] if !domains[organization].include? domain_id

            @api.resource(:organizations).call(:update, {
                                                 'id' => organization_id,
                                                 'organization' => {
                                                   'domain_ids' => domains[organization]
                                                 }
                                               })
          end

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
