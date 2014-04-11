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
# -= Organizations CSV =-
#
# Columns
#   Name
#     - Name of the organization.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "organization%d" -> "organization1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#   Org Label
#     - Label of the organization.
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "organization%d" -> "organization1"
#   Description
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class OrganizationsCommand < BaseCommand
    ORGLABEL = 'Org Label'
    DESCRIPTION = 'Description'

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, ORGLABEL, DESCRIPTION]
        @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
          csv << [organization['name'], 1, organization['label'], organization['description']]
        end
      end
    end

    def import
      @existing = {}
      @api.resource(:organizations).call(:index, {:per_page => 999999})['results'].each do |organization|
        @existing[organization['name']] = organization['label'] if organization
      end

      thread_import do |line|
        create_organizations_from_csv(line)
      end
    end

    def create_organizations_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        label = namify(line[ORGLABEL], number)
        if !@existing.include? name
          print "Creating organization '#{name}'... " if option_verbose?
          @api.resource(:organizations).call(:create, {
                                       'name' => name,
                                       'label' => label,
                                       'description' => line[DESCRIPTION]
                                     })
        else
          print "Updating organization '#{name}'... " if option_verbose?
          @api.resource(:organizations).call(:update, {
                                       'id' => label,
                                       'description' => line[DESCRIPTION]
                                     })
        end
        print "done\n" if option_verbose?
      end
    end
  end

  HammerCLICsv::CsvCommand.subcommand('organizations',
                                      'import or export organizations',
                                      HammerCLICsv::OrganizationsCommand)
end
