require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestContentHostsUsage < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --help})
      }
      assert_equal stderr, ''
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv content-hosts [OPTIONS]

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

  class TestContentHostsImport < MiniTest::Unit::TestCase
    def test_create_and_update
      start_vcr
      set_user 'admin'

      hostname = "host00001"

      stdout,stderr = capture {
        hammer.run(%W{organization list --search label=examplecorp})
      }
      stdout.split("\n").length.must_equal 5

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Example Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,1,4,1,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating content host '#{hostname}'...done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Updating content host '#{hostname}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(host list --search name=#{hostname}))
      }
      assert_equal stderr, ''
      assert_equal stdout.split("\n").length, 5

      stdout,stderr = capture {
        hammer.run(%W(host delete --name #{hostname}))
      }
      stop_vcr
    end
  end
end
