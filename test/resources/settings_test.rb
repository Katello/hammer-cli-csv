require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestSettingsUsage < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv settings --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
Usage:
     csv settings [OPTIONS]

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

  class TestSettingsImport < MiniTest::Unit::TestCase
    def test_update_settings
      start_vcr
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Count,Value
idle_timeout,1,60000
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv settings --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Updating setting 'idle_timeout'...done", lines[0]
      file.unlink
      stop_vcr
    end

    def test_update_settings_continue
      start_vcr
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Count,Value
badsetting,1,1234
idle_timeout,1,60000
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv settings --verbose --continue-on-error --file #{file.path}})
      }
      stderr.must_equal "Error: Setting 'badsetting' not found\nbadsetting,1,1234\n"
      lines = stdout.split("\n")
      assert_equal lines[0], "Updating setting 'idle_timeout'...done"
      file.unlink
      stop_vcr
    end
  end

end
