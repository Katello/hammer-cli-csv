require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestDomains < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv domains --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv domains [OPTIONS]

Options:
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end
  end
end
