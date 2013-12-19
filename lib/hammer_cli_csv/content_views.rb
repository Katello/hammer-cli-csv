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
require 'katello_api'
require 'foreman_api'
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
        @k_contentviewdefinition_api.index({'organization_id' => line[ORGANIZATION], 'page_size' => 999999, 'paged' => true})[0]['results'].each do |contentview|
          @existing_contentviews[line[ORGANIZATION]][contentview['name']] = contentview['id'] if contentview
        end
      end

      line[COUNT].to_i.times do |number|
        name = namify(line[NAME], number)
        contentview_id = @existing_contentviews[line[ORGANIZATION]][name]
        if !contentview_id
          print "Creating content view '#{name}'..." if option_verbose?
          contentview_id = @k_contentviewdefinition_api.create({
                                                                 'organization_id' => line[ORGANIZATION],
                                                                 'name' => name,
                                                                 'label' => labelize(name),
                                                                 'description' => line[DESCRIPTION],
                                                                 'composite' => false # TODO: add column?
                                                               })[0]['id']
          @existing_contentviews[line[ORGANIZATION]][name] = contentview_id
        else
          print "Updating content view '#{name}'..." if option_verbose?
          @k_contentviewdefinition_api.create({
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
          @k_repository_api.create({
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

  HammerCLI::MainCommand.subcommand("csv:contentviews", "import/export content views", HammerCLICsv::ContentViewsCommand)
end
