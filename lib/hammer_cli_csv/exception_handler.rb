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

require 'hammer_cli/exception_handler'

module HammerCLICsv
  class ExceptionHandler < HammerCLI::ExceptionHandler
    def mappings
      super + [
        [Exception, :handle_csv_exception],
        [RestClient::Forbidden, :handle_forbidden],
        [RestClient::UnprocessableEntity, :handle_unprocessable_entity],
        [ArgumentError, :handle_argument_error]
      ]
    end

    protected

    def handle_csv_exception(e)
      $stderr.puts e.message
      log_full_error e
      HammerCLI::EX_DATAERR
    end

    def handle_unprocessable_entity(e)
      response = JSON.parse(e.response)
      response = response[response.keys[0]]

      print_error response['full_messages']
      HammerCLI::EX_DATAERR
    end

    def handle_argument_error(e)
      print_error e.message
      log_full_error e
      HammerCLI::EX_USAGE
    end

    def handle_forbidden(e)
      print_error 'Forbidden - server refused to process the request'
      log_full_error e
      HammerCLI::EX_NOPERM
    end
  end
end
