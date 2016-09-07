require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestSubscriptions < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subscriptions --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
Usage:
     csv subscriptions [OPTIONS]

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

    def test_manifest_does_not_exist
      start_vcr
      set_user 'admin'

      file = Tempfile.new('subscriptions_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organization,Manifest File,Subscription Name,Quantity,Product SKU,Contract Number,Account Number
Manifest,Test Corporation,./test/data/doesnotexist.zip
Manifest Name,Test Corporation,TestCorp
Manifest URL,Test Corporation,https://access.stage.redhat.com/management/distributors/1234
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subscriptions --verbose --file #{file.path}})
      }
      assert_equal '', stdout
      lines = stderr.split("\n")
      assert_equal "Manifest upload failed:", lines[0]
      assert_match(/.*Error: No such file or directory.*/, lines[1])
      file.unlink
      stop_vcr
    end

    def test_portal_incorrect_login
      start_vcr
      set_user 'admin'

      file = Tempfile.new('subscriptions_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organization,Manifest File,Subscription Name,Quantity,Product SKU,Contract Number,Account Number
Manifest,Test Corporation,./test/data/doesnotexist.zip
Manifest Name,Test Corporation,TestCorp
Manifest URL,Test Corporation,https://access.stage.redhat.com/management/distributors/1234
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subscriptions --verbose --file #{file.path}
                      --in-portal --portal-username username --portal-password password})
      }
      assert_equal "Checking manifest 'TestCorp'...", stdout
      lines = stderr.split("\n")
      assert_equal "Error: 401 Unauthorized", lines[0]
      file.unlink
      stop_vcr
    end

    def test_portal_existing_subscription
      start_vcr
      set_user 'admin'

      username = ENV['PORTALUSERNAME'] || 'username'
      password = ENV['PORTALPASSWORD'] || 'password'

      manifestfile = Tempfile.new('subscriptions_test')
      file = Tempfile.new('subscriptions_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organization,Manifest File,Subscription Name,Quantity,Product SKU,Contract Number,Account Number
Manifest,Test Corporation,#{manifestfile.path}
Manifest Name,Test Corporation,TestCorp
Manifest URL,Test Corporation,https://access.stage.redhat.com/management/distributors/1234
Subscription,Test Corporation,,"Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)",200,RH00004,10999113,5700573,2016-06-20T04:00:00.000+0000,2017-06-20T03:59:59.000+0000
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subscriptions --verbose --file #{file.path}
                      --in-portal --portal-username #{username} --portal-password #{password}
                      --portal https://subscription.rhn.stage.redhat.com:443})
      }
      assert_equal stderr, ''
      assert_equal stdout, <<-OUTPUT
Checking manifest 'TestCorp'...done
'Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)' of quantity 200 already attached
Downloading manifest for organization 'Test Corporation...writing to file '#{manifestfile.path}'...done
OUTPUT
      file.unlink
      manifestfile.unlink
      stop_vcr
    end
  end
end
