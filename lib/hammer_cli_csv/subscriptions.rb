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
require 'json'
require 'csv'
require 'uri'

module HammerCLICsv
  class CsvCommand
    class SubscriptionsCommand < BaseCommand
      command_name 'subscriptions'
      desc         'import or export subscriptions'

      ORGANIZATION = 'Organization'
      MANIFEST = 'Manifest File'

      def export
        # TODO
      end

      def import
        thread_import do |line|
          create_subscriptions_from_csv(line)
        end
      end

      def create_subscriptions_from_csv(line)
        args = %W{ subscription upload --file #{ line[MANIFEST] }
                   --organization-id #{ foreman_organization(:name => line[ORGANIZATION]) } }
        hammer.run(args)
      rescue RuntimeError => e
        raise "#{e}\n       #{line}"
      end

      def ctx
        {
          :interactive => false,
          :username => 'admin',
          :password => 'changeme'
        }
      end

      def hammer(context = nil)
        HammerCLI::MainCommand.new('', context || ctx)
      end

    end
  end
end
