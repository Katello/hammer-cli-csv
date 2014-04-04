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
# -= Systems CSV =-
#
# Columns
#   Name
#     - System name
#     - May contain '%d' which will be replaced with current iteration number of Count
#     - eg. "os%d" -> "os1"
#   Count
#     - Number of times to iterate on this line of the CSV file


require 'hammer_cli'
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class ContentViewsCommand < BaseCommand

    ORGANIZATION = 'Organization'
    DESCRIPTION = 'Description'
    PRODUCT = 'Product'
    REPOSITORY = 'Repository'

    def export
      # TODO
    end

    def import
      @existing_contentviews = {}

      thread_import do |line|
        create_contentviews_from_csv(line)
      end
    end

    def create_contentviews_from_csv(line)
      if !@existing_contentviews[line[ORGANIZATION]]
        @existing_contentviews[line[ORGANIZATION]] ||= {}
        @api.resource(:contentviewdefinitions).call(:index, {'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true})['results'].each do |contentview|
          @existing_contentviews[line[ORGANIZATION]][contentview['name']] = contentview['id'] if contentview
        end
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        contentview_id = @existing_contentviews[line[ORGANIZATION]][name]
        if !contentview_id
          print "Creating content view '#{name}'..." if option_verbose?
          contentview_id = @api.resource(:contentviewdefinitions).call(:create, {
                                                                 'organization_id' => line[ORGANIZATION],
                                                                 'name' => name,
                                                                 'label' => labelize(name),
                                                                 'description' => line[DESCRIPTION],
                                                                 'composite' => false # TODO: add column?
                                                               })['id']
          @existing_contentviews[line[ORGANIZATION]][name] = contentview_id
        else
          print "Updating content view '#{name}'..." if option_verbose?
          @api.resource(:contentviewdefinitions).call(:create, {
                                                'description' => line[DESCRIPTION],
                                              })
        end

        if line[REPOSITORY]
          puts "UPDATING REPOSITORY"
        elsif line[PRODUCT]
          puts "UPDATING PRODUCT"
        end
        print "done\n" if option_verbose?

=begin
        # Only creating repositories, not updating
        repository_name = namify(line[REPOSITORY], number)
        if !@existing_repositories[line[ORGANIZATION] + name][labelize(repository_name)]
          print "Creating repository '#{repository_name}' in contentview '#{name}'..." if option_verbose?
          @api.resource(:repositorys).call(:create, {
                                     'name' => repository_name,
                                     'label' => labelize(repository_name),
                                     'contentview_id' => contentview_id,
                                     'url' => line[REPOSITORY_URL],
                                     'content_type' => line[REPOSITORY_TYPE]
                                   })
          print "done\n" if option_verbose?
        end
=end
      end

    rescue RuntimeError => e
      raise "#{e}\n       #{line}"
    end
  end

  HammerCLICsv::CsvCommand.subcommand("content-views",
                                      "import or export content-views",
                                      HammerCLICsv::ContentViewsCommand)
end
