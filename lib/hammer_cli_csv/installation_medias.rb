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
    class InstallationMediasCommand < BaseCommand
      command_name 'installation-medias'
      desc         'import or export installation media'

      OSFAMILY = 'OS Family'
      PATH = 'Path'
      ORGANIZATIONS = 'Organizations'

      def export
        CSV.open(option_csv_file || '/dev/stdout', 'wb', {:force_quotes => true}) do |csv|
          csv << [NAME, COUNT, PATH, OSFAMILY]
          @api.resource(:media).call(:index, {:per_page => 999999})['results'].each do |installation_media|
            name = installation_media['name']
            count = 1
            path = installation_media['path']
            os_family = installation_media['os_family']
            csv << [name, count, path, os_family]
          end
        end
      end

      def import
        @existing = {}
        @api.resource(:media).call(:index, {:per_page => 999999})['results'].each do |installation_media|
          @existing[installation_media['name']] = installation_media['id'] if installation_media
        end

        thread_import do |line|
          create_installation_medias_from_csv(line)
        end
      end

      def create_installation_medias_from_csv(line)
        line[COUNT].to_i.times do |number|
          name = namify(line[NAME], number)
          if !@existing.include? name
            print "Creating installation_media '#{name}'..." if option_verbose?
            installation_media_id = @api.resource(:media).call(:create, {
                                                       'name' => name
                                                     })['id']
          else
            print "Updating installation_media '#{name}'..." if option_verbose?
            installation_media_id = @api.resource(:media).call(:update, {
                                                       'id' => @existing[name],
                                                       'name' => name
                                                     })['id']
          end

          # Update associated resources
          installation_medias ||= {}
          CSV.parse_line(line[ORGANIZATIONS]).each do |organization|
            organization_id = foreman_organization(:name => organization)
            if installation_medias[organization].nil?
              installation_medias[organization] = @api.resource(:organizations).call(:show, {'id' => organization_id})['installation_medias'].collect do |installation_media|
                installation_media['id']
              end
            end
            installation_medias[organization] += [installation_media_id] if !installation_medias[organization].include? installation_media_id

            @api.resource(:organizations).call(:update, {
                                                 'id' => organization_id,
                                                 'organization' => {
                                                   'installation_media_ids' => installation_medias[organization]
                                                 }
                                               })
          end

          print "done\n" if option_verbose?
        end
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end
    end
  end
end
