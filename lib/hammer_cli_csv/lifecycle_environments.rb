# Copyright (c) 2014 Red Hat
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
# -= Environments CSV =-
#
# Columns
#   Name
#     - Environment name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file
#

require 'hammer_cli'
require 'json'
require 'csv'

module HammerCLICsv
  class LifecycleEnvironmentsCommand < BaseCommand

    LABEL = "Label"
    ORGANIZATION = "Organization"
    PRIORENVIRONMENT = "Prior Environment"
    DESCRIPTION = "Description"

    def export
      CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
        csv << [NAME, COUNT, LABEL, ORGANIZATION, PRIORENVIRONMENT, DESCRIPTION]
        @k_organization_api.index({'per_page' => 999999})[0]['results'].each do |organization|
          @k_environment_api.index({
                                     'per_page' => 999999,
                                     'organization_id' => organization['label']
                                   })[0]['results'].each do |environment|
            if environment['label'] != 'Library'
              name = environment['name']
              count = 1
              label = environment['label']
              prior = environment['prior']
              description = environment['description']
              csv << [name, count, label, organization['name'], prior, description]
            end
          end
        end
      end
    end

    def import
      @existing = {}
      @k_organization_api.index({'per_page' => 999999})[0]['results'].each do |organization|
        @k_environment_api.index({
                                   'per_page' => 999999,
                                   'organization_id' => katello_organization(:name => organization['name'])
                                 })[0]['results'].each do |environment|
          @existing[organization['name']] ||= {}
          @existing[organization['name']][environment['name']] = environment['id'] if environment
        end
      end

      thread_import do |line|
        create_environments_from_csv(line)
      end
    end

    def create_environments_from_csv(line)
      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        label = namify(line[LABEL], number)
        prior = namify(line[PRIORENVIRONMENT], number)
        raise "Organization '#{line[ORGANIZATION]}' does not exist" if !@existing.include? line[ORGANIZATION]
        if !@existing[line[ORGANIZATION]].include? name
          print "Creating environment '#{name}'..." if option_verbose?
          @k_environment_api.create({
                                      'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                      'name' => name,
                                      'label' => label,
                                      'prior' => katello_environment(line[ORGANIZATION], :name => prior),
                                      'description' => line[DESCRIPTION]
                                    })
        else
          print "Updating environment '#{name}'..." if option_verbose?
          @k_environment_api.update({
                                      'id' => katello_environment(line[ORGANIZATION], :name => label),
                                      'name' => name,
                                      'new_name' => name,
                                      'organization_id' => katello_organization(:name => line[ORGANIZATION]),
                                      'prior' => prior,
                                      'description' => line[DESCRIPTION]
                                    })
        end
        print "done\n" if option_verbose?
      end
    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLI::MainCommand.subcommand("csv:lifecycleenv", "Import or export lifecycle environments", HammerCLICsv::LifecycleEnvironmentsCommand)
end
