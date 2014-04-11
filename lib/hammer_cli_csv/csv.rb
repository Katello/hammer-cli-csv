
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

require 'hammer_cli'
require 'hammer_cli/exit_codes'

module HammerCLICsv
  class CsvCommand < HammerCLI::AbstractCommand
    # def request_help
    #   puts _("import to, or export from a running foretello server")
    #   exit(HammerCLI::EX_OK)
    # end
  end

  HammerCLI::MainCommand.subcommand("csv",
                                    _("import to, or export from a running foretello server"),
                                    HammerCLICsv::CsvCommand)
end
