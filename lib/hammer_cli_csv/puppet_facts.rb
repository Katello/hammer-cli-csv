module HammerCLICsv
  class CsvCommand
    class PuppetFactsCommand < BaseCommand
      command_name 'puppet-facts'
      desc         'import or export puppet facts'

      ORGANIZATION = 'Organization'
      FACTS = 'Puppet Facts'

      SEPARATOR = ' = '

      def export(csv)
        csv << [NAME, ORGANIZATION, FACTS]

        search_options = {:per_page => 999999}
        search_options['search'] = "organization=\"#{option_organization}\"" if option_organization
        @api.resource(:hosts).call(:index, search_options)['results'].each do |host|
          facts = @api.resource(:fact_values).call(:index, {
                                                             'search' => "host = #{host['name']}",
                                                             'per_page' => 999999
                                                           })['results']
          facts = @api.resource(:fact_values).call(:index, {
                                                             'search' => "host = #{host['name']}",
                                                             'per_page' => 999999
                                                           })['results'][host['name']]
          facts ||= {}

          values = CSV.generate do |column|
            column << facts.collect do |fact_name, fact_value|
              "#{fact_name}#{SEPARATOR}#{fact_value}"
            end
          end
          values.delete!("\n")

          csv << [host['name'], host['organization_name'], values]
        end
      end

      def import
        thread_import(true) do |line|
          create_puppetfacts_from_csv(line)
        end
      end

      def create_puppetfacts_from_csv(line)
        return if option_organization && line[ORGANIZATION] != option_organization

        count(line[COUNT]).times do |number|
          name = namify(line[NAME], number)
          print "Updating puppetfacts '#{name}'..." if option_verbose?
          facts = {}
          collect_column(line[FACTS]) do |fact|
            (fact_name, fact_value) = fact.split(SEPARATOR)
            facts[fact_name] = fact_value
          end

          # Namify the values if the host name was namified
          if name != line[NAME]
            facts.each do |fact, value|
              facts[fact] = namify(value, number) unless value.nil? || value.empty?
            end
          end

          @api.resource(:hosts).call(:facts, {
                                               'name' => name,
                                               'facts' => facts
                                             })
          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
