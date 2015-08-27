require 'hammer_cli'
require 'hammer_cli/exit_codes'

module HammerCLICsv
  class CsvCommand < HammerCLI::AbstractCommand
  end

  HammerCLI::MainCommand.subcommand('csv',
                                    _('import to, or export from a running foretello server'),
                                    HammerCLICsv::CsvCommand)
end
