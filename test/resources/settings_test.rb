require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestSettingsUsage < MiniTest::Unit::TestCase

    def test_usage
      set_user 'admin'

      stdout,stderr = run_with_vcr do
        hammer.run(%W{csv settings --help})
      end
      assert_equal stderr, ''
      assert_equal stdout, <<-HELP
Usage:
     csv settings [OPTIONS]

Options:
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --csv-export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
    end
  end

  class TestSettingsImport < MiniTest::Unit::TestCase
    def test_update_settings
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Count,Value
idle_timeout,1,60000
FILE
      file.rewind

      stdout,stderr = run_with_vcr do
        hammer.run(%W{csv settings --verbose --file #{file.path}})
      end
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal lines[0], "Updating setting 'idle_timeout'...done"
      file.unlink
    end
  end

end
