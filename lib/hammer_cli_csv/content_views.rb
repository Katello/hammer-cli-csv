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

      LABEL = 'Label'
      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      COMPOSITE = 'Composite'
      REPOSITORIES = 'Repositories or Composites'
      FILTERS = 'Filters'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, LABEL, ORGANIZATION, COMPOSITE, REPOSITORIES, FILTERS]
          @api.resource(:organizations).call(:index, {
              :per_page => 999999
          })['results'].each do |organization|
            composite_contentviews = []
            @api.resource(:content_views).call(:index, {
                'per_page' => 999999,
                'organization_id' => organization['id'],
                'nondefault' => true
            })['results'].each do |contentview|

              filters = CSV.generate do |column|
                column << @api.resource(:content_view_filters).call(:index, {
                    'content_view_id' => contentview['id']
                })['results'].collect do |filter|
                  rules = filter['rules'].collect do |rule|
                    rule['name']
                  end
                  in_or_out = filter['inclusion'] == true ? 'Include' : 'Exclude'
                  if filter['type'] == 'rpm'
                    "#{ in_or_out }|#{ filter['type'] }|#{ rules.join(',')}"
                  elsif filter['type'] == 'erratum'
                    "#{ in_or_out }|#{ filter['type'] }|#{ rules['types'].join(',')}"
                  else
                    "???? #{filter['type']}"
                  end
                end
              end
              filters.delete!("\n")

              name = contentview['name']
              label = contentview['label']
              orgname = organization['name']
              composite = contentview['composite'] == true ? 'Yes' : 'No'
              if composite == 'Yes'
                contentviews = CSV.generate do |column|
                  column << contentview['components'].collect do |component|
                    component['content_view']['name']
                  end
                end
                contentviews.delete!("\n")
                composite_contentviews << [name, 1, label, orgname, composite, contentviews, filters]
              else
                repositories = export_column(contentview, 'repositories', 'name')
                csv << [name, 1, label, orgname, composite, repositories, filters]
              end
            end
            composite_contentviews.each do |contentview|
              csv << contentview
            end
          end
        end
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
          @api.resource(:content_views).call(:index, {
              'per_page' => 999999,
              'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
              'nondefault' => true
          })['results'].each do |contentview|
            @existing_contentviews[line[ORGANIZATION]][contentview['name']] = contentview['id'] if contentview
          end
        end

        is_composite = line[COMPOSITE] == 'Yes' ? true : false

        if is_composite
          composite_ids = collect_column(line[REPOSITORIES]) do |composite|
            # TODO: export version and use it here
            katello_contentviewversion(line[ORGANIZATION], composite, 1)
          end
        else
          repository_ids = collect_column(line[REPOSITORIES]) do |repository|
            katello_repository(line[ORGANIZATION], :name => repository)
          end
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          contentview_id = @existing_contentviews[line[ORGANIZATION]][name]
          if !contentview_id
            print "Creating content view '#{name}'..." if option_verbose?
            options = {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => name,
                'label' => labelize(name),
                'description' => line[DESCRIPTION],
                'composite' => is_composite
            }
            if is_composite
              options['component_ids'] = composite_ids
            else
              options['repository_ids'] = repository_ids
            end
            contentview_id = @api.resource(:content_views).call(:create, options)['id']
            @existing_contentviews[line[ORGANIZATION]][name] = contentview_id
            publish = true
          else
            print "Updating content view '#{name}'..." if option_verbose?
            options = {
                'id' => contentview_id,
                'description' => line[DESCRIPTION]
            }
            if is_composite
              options['component_ids'] = composite_ids
            else
              options['repository_ids'] = repository_ids
            end
            contentview = @api.resource(:content_views).call(:update, options)
            publish = contentview['versions'].empty?
          end

          # Content views cannot be used in composites unless a publish has occurred
          # TODO: this command cannot be called more than once during a run, why?
          if publish
            args = %W{
              --server #{ @server } --username #{ @username } --password #{ @server }
              content-view publish --id #{ contentview_id }
              --organization-id #{ foreman_organization(:name => line[ORGANIZATION]) }
            }
            hammer.run(args)
          end

          puts 'done' if option_verbose?
        end

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
