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
require 'katello_api'
require 'json'
require 'csv'

module HammerCLICsv
  class OrganizationsCommand < BaseCommand

    def initialize(*args)
      super(args)
      @organization_api = KatelloApi::Resources::Organization.new(@init_options)
    end

    def execute
      csv_export? ? export : import

      HammerCLI::EX_OK
    end

    def export
      CSV.open(csv_file, 'wb') do |csv|
        csv << ['Name','Count','Org Label', 'Description']
        @organization_api.index[0].each do |organization|
          csv << [organization['name'], 1, organization['label'], organization['description']]
        end
      end
    end

    def import
      @existing = {}
      @organization_api.index[0].each do |organization|
          @existing[organization['name']] = organization['label']
      end

      thread_import do |line|
        create_organizations_from_csv(line)
      end
    end

    def create_organizations_from_csv(line)
      details = parse_organization_csv(line)

      details[:count].times do |number|
        name = namify(details[:name_format], number)
        label = namify(details[:label_format], number)
        if !@existing.include? name
          puts "Creating organization '#{name}'" if verbose?
          @organization_api.create({
                             :organization => {
                               :name => name,
                               :label => label,
                               :description => details[:description]
                             }
                           }, HEADERS)
        else
          puts "Updating organization '#{name}'" if verbose?
          @organization_api.update({
                             'id' => label,
                             :organization => {
                               :name => name,
                               :description => details[:description]
                             }
                           }, HEADERS)
        end
      end
    end

    def parse_organization_csv(line)
      keys = [:name_format, :count, :label_format, :description]
      details = CSV.parse(line).map { |a| Hash[keys.zip(a)] }[0]

      details[:count] = details[:count].to_i

      details
    end
  end

  HammerCLI::MainCommand.subcommand("csv:organizations", "ping the katello server", HammerCLICsv::OrganizationsCommand)
end
