require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestActivationKeysUsage < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
Usage:
     csv activation-keys [OPTIONS]

Options:
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --itemized-subscriptions      Export one subscription per row, only process update subscriptions on import
 --organization ORGANIZATION   Only process organization matching this name
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end
  end

  class TestActivationKeysImport < MiniTest::Unit::TestCase
    def test_create_and_update
      start_vcr
      set_user 'admin'

      @name = "testakey1"

      file = Tempfile.new('activation_keys_test')
      file.write("Name,Organization,Description,Limit,Environment,Content View,Host Collections,Auto-Attach,Service Level,Release Version,Subscriptions\n")
      file.write("#{@name},Test Corporation,,,,Default Organization View,"",No,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Creating activation key '#{@name}'...done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating activation key '#{@name}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache activation-key list --organization Test\ Corporation --search name=#{@name}))
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n").length, 5

      id = stdout.split("\n")[3].split(" ")[0]
      stdout,stderr = capture {
        hammer.run(%W(--reload-cache activation-key delete --id #{id}))
      }

      stop_vcr
    end
  end
end
