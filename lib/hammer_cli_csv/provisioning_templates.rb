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
      TEMPLATE = 'Template'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, ORGANIZATIONS, LOCATIONS, KIND, TEMPLATE]
          @api.resource(:config_templates).call(:index, {
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
        @api.resource(:config_templates).call(:index, {
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
            template_id = @api.resource(:config_templates).call(:create, {
                'name' => name,
                'snippet' => line[KIND] == 'snippet',
                'template_kind_id' => line[KIND] == 'snippet' ? nil : foreman_template_kind(:name => line[KIND]),
                'organization_ids' => organizations,
                'location_ids' => locations,
                'template' => line[TEMPLATE]
            })['id']
          else
            print "Updating provisioning template '#{name}'..." if option_verbose?
            template_id = @api.resource(:config_templates).call(:update, {
                'id' => @existing[name],
                'name' => name,
                'snippet' => line[KIND] == 'snippet',
                'template_kind_id' => line[KIND] == 'snippet' ? nil : foreman_template_kind(:name => line[KIND]),
                'organization_ids' => organizations,
                'location_ids' => locations,
                'template' => line[TEMPLATE]
            })['id']
          end
          @existing[name] = template_id

          # Update associated resources
          template_organizations ||= {}
          organizations.each do |organization_id|
            if template_organizations[organization_id].nil?
              template_organizations[organization_id] = @api.resource(:organizations).call(:show, {
                  'id' => organization_id
              })['config_templates'].collect do |template|
                template['id']
              end
            end
            if !template_organizations[organization_id].include? template_id
              template_organizations[organization_id] += [template_id]
              @api.resource(:organizations).call(:update, {
                  'id' => organization_id,
                  'organization' => {
                      'config_template_ids' => template_organizations[organization_id]
                  }
              })
            end
          end
          template_locations ||= {}
          locations.each do |location_id|
            if template_locations[location_id].nil?
              template_locations[location_id] = @api.resource(:locations).call(:show, {
                  'id' => location_id
              })['config_templates'].collect do |template|
                template['id']
              end
            end
            if !template_locations[location_id].include? template_id
              template_locations[location_id] += [template_id]
              @api.resource(:locations).call(:update, {
                  'id' => location_id,
                  'location' => {
                      'config_template_ids' => template_locations[location_id]
                  }
              })
            end
          end

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line[NAME]}"
      end
    end
  end
end
