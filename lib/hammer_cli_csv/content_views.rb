require 'hammer_cli_foreman'
require 'hammer_cli_foreman_tasks'

module HammerCLICsv
  class CsvCommand
    class ContentViewsCommand < BaseCommand
      include ::HammerCLIForemanTasks::Helper

      command_name 'content-views'
      desc         'import or export content-views'

      option %w(--[no-]publish), :flag, _('Publish content view on import (default false)')
      option %w(--[no-]promote), :flag,
        _('Publish and promote content view on import (default false)')

      LABEL = 'Label'
      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      COMPOSITE = 'Composite'
      REPOSITORIES = 'Repositories or Composites'
      ENVIRONMENTS = "Lifecycle Environments"

      def export(csv)
        if (options.keys & %w(option_promote option_publish)).any?
          fail _("Cannot pass publish or promote options on export")
        end

        csv << [NAME, LABEL, ORGANIZATION, COMPOSITE, REPOSITORIES, ENVIRONMENTS]
        @api.resource(:organizations).call(:index, {
            :per_page => 999999,
            :search => option_search
        })['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          composite_contentviews = []
          @api.resource(:content_views).call(:index, {
              'per_page' => 999999,
              'organization_id' => organization['id'],
              'nondefault' => true
          })['results'].each do |contentview|
            name = contentview['name']
            label = contentview['label']
            orgname = organization['name']
            environments = CSV.generate do |column|
              column << environment_names(contentview)
            end
            environments.delete!("\n")
            composite = contentview['composite'] == true ? 'Yes' : 'No'
            if composite == 'Yes'
              contentviews = CSV.generate do |column|
                column << contentview['components'].collect do |component|
                  component['content_view']['name']
                end
              end
              contentviews.delete!("\n")
              composite_contentviews << [name, label, orgname, composite, contentviews, environments]
            else
              repositories = export_column(contentview, 'repositories', 'name')
              csv << [name, label, orgname, composite, repositories, environments]
            end
          end
          composite_contentviews.each do |contentview|
            csv << contentview
          end
        end
      end

      def import
        if options.keys.include?('option_publish') && !option_publish? && option_promote?
          fail _("Cannot pass in --promote with --no-publish")
        end

        @existing_contentviews = {}

        thread_import do |line|
          create_contentviews_from_csv(line)
        end
      end

      def create_contentviews_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

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
            katello_contentviewversion(line[ORGANIZATION], composite)
          end
        else
          repository_ids = collect_column(line[REPOSITORIES]) do |repository|
            katello_repository(line[ORGANIZATION], :name => repository)
          end
        end

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          label = labelize(namify(line[LABEL] || line[NAME], number))

          contentview_id = @existing_contentviews[line[ORGANIZATION]][name]
          if !contentview_id
            puts _("Creating content view '%{name}'...") % {:name => name} if option_verbose?
            options = {
                'organization_id' => foreman_organization(:name => line[ORGANIZATION]),
                'name' => name,
                'label' => label,
                'description' => line[DESCRIPTION],
                'composite' => is_composite
            }
            contentview_id = @api.resource(:content_views).call(:create, options)['id']
            @existing_contentviews[line[ORGANIZATION]][name] = contentview_id
          else
            puts _("Updating content view '%{name}'...") % {:name => name} if option_verbose?
          end

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
          contentview_id = contentview['id']

          if option_publish? || option_promote?
            # Content views cannot be used in composites unless a publish has occurred
            if contentview['versions'].empty? && !line[ENVIRONMENTS].empty?
              publish_content_view(contentview_id, line)
            end

            if !line[ENVIRONMENTS].empty? && option_promote?
              promote_content_view(contentview_id, line)
            end
          end

          puts _('done') if option_verbose?
        end

      end

      def environment_names(contentview)
        names = []
        contentview['versions'].each do |version|
          version['environment_ids'].each do |environment_id|
            names << lifecycle_environment(contentview['organization']['name'], :id => environment_id)
          end
        end
        names.uniq
      end

      def publish_content_view(contentview_id, line)
        task_progress(@api.resource(:content_views).call(:publish, {
            'id' => contentview_id
        }))
      end

      def promote_content_view(contentview_id, line)
        contentview = @api.resource(:content_views).call(:show, {'id' => contentview_id})
        existing_names = environment_names(contentview)

        CSV.parse_line(line[ENVIRONMENTS]).each do |environment_name|
          next if environment_name == 'Library' || existing_names.include?(environment_name)

          version = contentview['versions'][-1]
          task_progress(@api.resource(:content_view_versions).call(:promote, {
              'id' => version['id'],
              'environment_id' => lifecycle_environment(line[ORGANIZATION], :name => environment_name),
              'force' => true
          }))
        end
      end
    end
  end
end
