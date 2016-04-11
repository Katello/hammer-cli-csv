require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'csv' do
  extend CommandTestHelper

  context "help" do
    it "displays supported options" do
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv --help})
      }
      stderr.must_equal ''
      stdout.must_equal <<-HELP
Usage:
     csv [OPTIONS] SUBCOMMAND [ARG] ...

Parameters:
 SUBCOMMAND                    subcommand
 [ARG] ...                     subcommand arguments

Subcommands:
 export                        export into directory
 import                        import by directory
 settings                      import or export settings

Options:
 -h, --help                    print help
HELP
    end
  end
end
