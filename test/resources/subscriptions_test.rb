require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestSubscriptionsUsage < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv subscriptions --help})
      }
      assert_equal stderr, ''
      assert_equal stdout, <<-HELP
Usage:
     csv subscriptions [OPTIONS]

Options:
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end
  end

  class TestSubscriptionsImport < MiniTest::Unit::TestCase
    def test_manifest_does_not_exist
      start_vcr
      set_user 'admin'

      file = Tempfile.new('subscriptions_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organization,Manifest File,Subscription Name,Quantity,Product SKU,Contract Number,Account Number
Manifest,Example Corporation,./test/data/doesnotexist.zip
# Manifest Name,Example Corporation,ExampleCorp
# Manifest URL,Example Corporation,https://access.stage.redhat.com/management/distributors/1234
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv subscriptions --verbose --file #{file.path}})
      }
      assert_equal stdout, ''
      lines = stderr.split("\n")
      assert_equal lines[0], "Manifest upload failed:"
      assert_match(/.*Error: No such file or directory.*/, lines[1])
      file.unlink
      stop_vcr
    end
  end
end
