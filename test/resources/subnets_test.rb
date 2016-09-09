require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestSubnets < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subnets --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv subnets [OPTIONS]

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

    def test_update_subnets
      start_vcr
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organizations,Locations,Network,Network Mask,Network Prefix,From,To,Domains,Gateway,DHCP Proxy,TFTP Proxy,DNS Proxy,DNS Primary,DNS Secondary,VLAN ID
Test Subnet,Test Corporation,Default Location,192.168.100.1,255.255.255.0,,"","",test.com,"","",katello.example.com,"","","",""
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subnets --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      # TODO: Cannot delete the subnet since it is associated with the domain so there is no way
      #       to clean up after this test. That means the subnet may already exist so assert
      #       w/o the "Creating" or "Updating" start of message
      assert_match(/.*subnet 'Test Subnet'...done/, lines[0])
      file.unlink
      stop_vcr
    end

    def test_update_subnets_continue
      start_vcr
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organizations,Locations,Network,Network Mask,Network Prefix,From,To,Domains,Gateway,DHCP Proxy,TFTP Proxy,DNS Proxy,DNS Primary,DNS Secondary,VLAN ID
Bad Subnet,Test Corporation,Default Location,192.168.100.1,255.255.255.0,24,bad,,test.com,"","",katello.example.com,"","","",""
Test Subnet,Test Corporation,Default Location,192.168.100.1,255.255.255.0,24,"","",example.com,"","",katello.example.com,"","","",""
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subnets --verbose --continue-on-error --file #{file.path}})
      }
      lines = stderr.split("\n")
      assert_equal "Error: 422 Unprocessable Entity", lines[0]
      lines = stdout.split("\n")
      assert_equal lines[0], "Creating subnet 'Bad Subnet'...Updating subnet 'Test Subnet'...done"
      file.unlink
      stop_vcr
    end
  end
end
