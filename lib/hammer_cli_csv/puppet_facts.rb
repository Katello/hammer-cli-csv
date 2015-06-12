module HammerCLICsv
  class CsvCommand
    class PuppetFactsCommand < BaseCommand
      command_name 'puppet-facts'
      desc         'import or export puppet facts'

      def export
        CSV.open(option_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          headers = [NAME, COUNT]
          # Extracted facts are always based upon the first host found, otherwise this would be an intensive
          # method to gather all the possible column names
          any_host = @api.resource(:hosts).call(:index, {:per_page => 1})['results'][0]
          headers += @api.resource(:puppetfactss).call(:index, {
                                                         'host_id' => any_host['name'],
                                                         'per_page' => 999999
                                                       })['results'][any_host['name']].keys
          csv << headers

          @api.resource(:hosts).call(:index, {:per_page => 999999})['results'].each do |host|
            line = [host['name'], 1]
            facts = @api.resource(:puppetfactss).call(:index, {'host_id' => host['name'], 'per_page' => 999999})[host['name']]
            facts ||= {}
            headers[2..-1].each do |fact_name|
              line << facts[fact_name] || ''
            end
            csv << line
          end
        end
      end

      def import
        @headers = nil

        thread_import(true) do |line|
          create_puppetfacts_from_csv(line)
        end
      end

      def create_puppetfacts_from_csv(line)
        if @headers.nil?
          @headers = line
          return
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          print "Updating puppetfacts '#{name}'..." if option_verbose?
          facts = line.to_hash
          facts.delete(NAME)
          facts.delete(COUNT)

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
