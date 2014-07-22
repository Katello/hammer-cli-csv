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

module HammerCLICsv
  class CsvCommand
    class ContentViewsCommand < BaseCommand
      command_name 'content-views'
      desc         'import or export content-views'

      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      COMPOSITE = 'Composite'
      REPOSITORIES = 'Repositories'

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
          @api.resource(:content_views)\
            .call(:index, {
                    'per_page' => 999999,
                    'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                    'nondefault' => true
                  })['results'].each do |contentview|
            @existing_contentviews[line[ORGANIZATION]][contentview['name']] = contentview['id'] if contentview
          end
        end

        repository_ids = collect_column(line[REPOSITORIES]) do |repository|
          katello_repository(line[ORGANIZATION], :name => repository)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          composite = line[COMPOSITE] == 'Yes' ? true : false

          contentview_id = @existing_contentviews[line[ORGANIZATION]][name]
          if !contentview_id
            print "Creating content view '#{name}'..." if option_verbose?
            contentview_id = @api.resource(:content_views)\
              .call(:create, {
                      'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                      'name' => name,
                      'label' => labelize(name),
                      'description' => line[DESCRIPTION],
                      'composite' => composite,
                      'repository_ids' => repository_ids
                    })['id']
            @existing_contentviews[line[ORGANIZATION]][name] = contentview_id
          else
            print "Updating content view '#{name}'..." if option_verbose?
            @api.resource(:content_views)\
              .call(:update, {
                      'id' => contentview_id,
                      'description' => line[DESCRIPTION],
                      'repository_ids' => repository_ids
                    })
          end
          puts 'done' if option_verbose?
        end

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
