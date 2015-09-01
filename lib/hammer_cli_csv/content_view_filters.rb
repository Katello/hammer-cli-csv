# NOTE:
#   rpm -qa --queryformat "%{NAME}|=|%{VERSION}-%{RELEASE},"

module HammerCLICsv
  class CsvCommand
    class ContentViewFiltersCommand < BaseCommand
      command_name 'content-view-filters'
      desc         'import or export content-view-filters'

      CONTENTVIEW = 'Content View'
      ORGANIZATION = 'Organization'
      DESCRIPTION = 'Description'
      TYPE = 'Type'
      REPOSITORIES = 'Repositories'
      RULES = 'Rules'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => false}) do |csv|
          csv << [NAME, COUNT, CONTENTVIEW, ORGANIZATION, TYPE, DESCRIPTION, REPOSITORIES, RULES]
          @api.resource(:organizations).call(:index, {
              :per_page => 999999
          })['results'].each do |organization|
            next if option_organization && organization['name'] != option_organization

            composite_contentviews = []
            @api.resource(:content_views).call(:index, {
                'per_page' => 999999,
                'organization_id' => organization['id'],
                'nondefault' => true
            })['results'].each do |contentview|
              @api.resource(:content_view_filters).call(:index, {
                  'content_view_id' => contentview['id']
              })['results'].collect do |filter|
                filter_type = "#{filter['inclusion'] == true ? 'Include' : 'Exclude'} #{filter['type']}"

                case filter['type']
                when /rpm/
                  rules = CSV.generate do |column|
                    column << filter['rules'].collect do |rule|
                      if rule['version']
                        "#{rule['name']}|=|#{rule['version']}"
                      elsif rule['min_version'] && rule['max_version']
                        "#{rule['name']}|-|#{rule['min_version']},#{rule['max_version']}"
                      elsif rule['min_version']
                        "#{rule['name']}|>|#{rule['min_version']}"
                      elsif rule['max_version']
                        "#{rule['name']}|<|#{rule['max_version']}"
                      end
                    end
                  end
                  rules.delete!("\n")
                when /erratum/
                  rules = CSV.generate do |column|
                    rule = filter['rules'][0]
                    conditions = []
                    conditions << "start = #{DateTime.parse(rule['start_date']).strftime('%F')}" if rule['start_date']
                    conditions << "end = #{DateTime.parse(rule['end_date']).strftime('%F')}" if rule['end_date']
                    conditions += rule['types']
                    column << conditions
                  end
                  rules.delete!("\n")
                when /package_group/
                else
                  raise "Unknown filter rule type '#{filter['type']}'"
                end

                name = contentview['name']
                repositories = export_column(filter, 'repositories', 'name')
                csv << [name, 1, contentview['name'], organization['name'], filter_type, filter['description'],
                        repositories, rules]
              end
            end
          end
        end
      end

      def import
        @existing_filters = {}

        thread_import do |line|
          create_filters_from_csv(line)
        end
      end

      def create_filters_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        @existing_filters[line[ORGANIZATION]] ||= {}
        if !@existing_filters[line[ORGANIZATION]][line[CONTENTVIEW]]
          @existing_filters[line[ORGANIZATION]][line[CONTENTVIEW]] ||= {}
          @api.resource(:content_view_filters).call(:index, {
              'per_page' => 999999,
              'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW])
          })['results'].each do |filter|
            @existing_filters[line[ORGANIZATION]][line[CONTENTVIEW]][filter['name']] = filter['id'] if filter
          end
        end

        repository_ids = collect_column(line[REPOSITORIES]) do |repository|
          katello_repository(line[ORGANIZATION], :name => repository)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)

          filter_id = @existing_filters[line[ORGANIZATION]][line[CONTENTVIEW]][name]
          if !filter_id
            print "Creating filter '#{name}' for content view filter '#{line[CONTENTVIEW]}'..." if option_verbose?
            filter_id = @api.resource(:content_view_filters).call(:create, {
                'content_view_id' => katello_contentview(line[ORGANIZATION], :name => line[CONTENTVIEW]),
                'name' => name,
                'description' => line[DESCRIPTION],
                'type' => filter_type(line[TYPE]),
                'inclusion' => filter_inclusion?(line[TYPE]),
                'repository_ids' => repository_ids
            })['id']
            @existing_filters[line[ORGANIZATION]][name] = filter_id
          else
            print "Updating filter '#{name}' for content view filter '#{line[CONTENTVIEW]}'..." if option_verbose?
            @api.resource(:content_view_filters).call(:update, {
                'id' => filter_id,
                'description' => line[DESCRIPTION],
                'type' => filter_type(line[TYPE]),
                'inclusion' => filter_inclusion?(line[TYPE]),
                'repository_ids' => repository_ids
            })
          end

          @existing_rules ||= {}
          @existing_rules[line[ORGANIZATION]] ||= {}
          @existing_rules[line[ORGANIZATION]][line[CONTENTVIEW]] ||= {}
          @api.resource(:content_view_filter_rules).call(:index, {
              'per_page' => 999999,
              'content_view_filter_id' => filter_id
          })['results'].each do |rule|
            @existing_rules[line[ORGANIZATION]][line[CONTENTVIEW]][rule['name']] = rule
          end

          collect_column(line[RULES]) do |rule|
            name, type, version = rule.split('|')
            params = {
              'content_view_filter_id' => filter_id,
              'name' => name
            }
            if type == '='
              params['type'] = 'equal',
                               params['version'] = version
            elsif type == '<'
              params['type'] = 'less',
                               params['max_version'] = version
            elsif type == '>'
              params['type'] = 'greater',
                               params['min_version'] = version
            elsif type == '-'
              params['type'] = 'range',
                               min_version, max_version = version.split(',')
              params['min_version'] = min_version
              params['max_version'] = max_version
            else
              raise "Unknown type '#{type}' from '#{line[RULES]}'"
            end

            rule = @existing_rules[line[ORGANIZATION]][line[CONTENTVIEW]][name]
            if !rule
              print "." if option_verbose?
              rule = @api.resource(:content_view_filter_rules).call(:create, params)
              @existing_rules[line[ORGANIZATION]][line[CONTENTVIEW]][rule['name']] = rule
            else
              print "." if option_verbose?
              params['id'] = rule['id']
              @api.resource(:content_view_filter_rules).call(:update, params)
            end
          end

          puts 'done' if option_verbose?
        end

      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      private

      def filter_type(type)
        if type.split[1] == 'RPM'
          'rpm'
        else
          'unknown'
        end
      end

      def filter_inclusion?(type)
        if type.split[0] == 'Include'
          true
        else
          false
        end
      end
    end
  end
end
