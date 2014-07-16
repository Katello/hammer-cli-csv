# Copyright 2014 Red Hat, Inc.
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
    class ProvisioningTemplatesCommand < BaseCommand
      command_name 'provisioning-templates'
      desc         'import or export provisioning templates'

      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      KIND = 'Kind'
      SOURCE = 'Source'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, KIND, SOURCE]
          @api.resource(:config_templates)
            .call(:index, {
                    :per_page => 999999
                  })['results'].each do |template_id|
            template = @api.resource(:config_templates).call(:show, {:id => template_id['id']})
            name = template['name']
            count = 1
            kind = template['snippet'] ? 'snippet' : template['template_kind_name']
            organizations = export_column(template, 'organizations', 'name')
            locations = export_column(template, 'locations', 'name')
            unless name == 'Boot disk iPXE - generic host' || name == 'Boot disk iPXE - host'
              csv << [name, count, organizations, locations, kind, template['template']]
            end
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:config_templates)
          .call(:index, {
                  :per_page => 999999
                })['results'].each do |template|
          @existing[template['name']] = template['id'] if template
        end

        thread_import do |line|
          create_templates_from_csv(line)
        end
      end

      def create_templates_from_csv(line)
        organizations = collect_column(line[ORGANIZATIONS]) do |organization|
          foreman_organization(:name => organization)
        end
        locations = collect_column(line[LOCATIONS]) do |location|
          foreman_location(:name => location)
        end

        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating provisioning template '#{name}'..." if option_verbose?
            id = @api.resource(:config_templates)
              .call(:create, {
                      'name' => name,
                      'snippet' => line[KIND] == 'snippet',
                      'template_kind_id' => line[KIND] == 'snippet' ? nil : foreman_template_kind(:name => line[KIND]),
                      'organizations' => organizations,
                      'locations' => locations
                    })['id']
          else
            print "Updating provisioning template '#{name}'..." if option_verbose?
            id = @api.resource(:config_template)
              .call(:update, {
                      'id' => @existing[name],
                      'name' => name,
                      'organizations' => organizations,
                      'locations' => locations
                    })['id']
          end
          @existing[name] = id

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line[NAME]}"
      end
    end
  end
end
