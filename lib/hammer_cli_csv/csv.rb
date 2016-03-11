require 'hammer_cli'
require 'hammer_cli/exit_codes'

module HammerCLICsv
  class CsvCommand < HammerCLI::AbstractCommand
    def help
      self.class.help(invocation_path, CsvSortedBuilder.new)
    end

    class CsvSortedBuilder < SortedBuilder
      def add_list(heading, items)
        items.delete_if do |item|
          if item.class == Clamp::Subcommand::Definition
            !item.subcommand_class.supported?
          else
            false
          end
        end
        super(heading, items)
      end
    end
  end

  HammerCLI::MainCommand.subcommand('csv',
                                    _('import to or export from a running foreman server'),
                                    HammerCLICsv::CsvCommand)
end
