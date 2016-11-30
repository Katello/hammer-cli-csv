require './test/csv_test_helper'
require './lib/hammer_cli_csv'

# rubocop:disable LineLength
module Resources
  class TestContentHosts < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
Usage:
     csv content-hosts [OPTIONS]

Options:
 --columns COLUMN_NAMES        Comma separated list of column names to export
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --itemized-subscriptions      Export one subscription per row, only process update subscriptions on import
 --organization ORGANIZATION   Only process organization matching this name
 --search SEARCH               Only export search results
 -h, --help                    print help
 -v, --verbose                 be verbose

Columns:
 Name - Name of resource
 Search - Search for matching names during import (overrides 'Name' column)
 Organization - Organization name
 Environment - Lifecycle environment name
 Content View - Content view name
 Host Collections - Comma separated list of host collection names
 Virtual - Is a virtual host, Yes or No
 Guest of Host - Hypervisor host name for virtual hosts
 OS - Operating system
 Arch - Architecture
 Sockets - Number of sockets
 RAM - Quantity of RAM in bytes
 Cores - Number of cores
 SLA - Service Level Agreement value
 Products - Comma separated list of products, each of the format \"<sku>|<name>\"
 Subscriptions - Comma separated list of subscriptions, each of the format "<quantity>|<sku>|<name>|<contract>|<account>"
 Subscription Name - Subscription name (only applicable for --itemized-subscriptions)
 Subscription Type - Subscription type (only applicable for --itemized-subscriptions)
 Subscription Quantity - Subscription quantity (only applicable for --itemized-subscriptions)
 Subscription SKU - Subscription SKU (only applicable for --itemized-subscriptions)
 Subscription Contract - Subscription contract number (only applicable for --itemized-subscriptions)
 Subscription Account - Subscription account number (only applicable for --itemized-subscriptions)
 Subscription Start - Subscription start date (only applicable for --itemized-subscriptions)
 Subscription End - Subscription end date (only applicable for --itemized-subscriptions)
HELP
      stop_vcr
    end

    def test_export_with_columns
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --columns Abc,Def})
      }
      assert_equal "Error: --columns option only relevant with --export\n", stderr
      assert_equal stdout, ''

      stop_vcr
    end

    def test_create_and_update
      start_vcr
      set_user 'admin'

      hostname = "testhost1"

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Test Corporation,Library,Default Organization View,No,,RHEL 6.4,x86_64,1,4,1,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Creating content host '#{hostname}'...done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating content host '#{hostname}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache host list --search name=#{hostname}))
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n").length, 5
      host_delete(hostname)

      stop_vcr
    end

    def test_export
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n")[0], "Name,Organization,Environment,Content View,Host Collections,Virtual,Guest of Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions"
      stop_vcr
    end

    def test_export_subscriptions
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --itemized-subscriptions --organization Test\ Corporation})
      }
      assert_equal '', stderr

      assert_equal stdout.split("\n")[0], "Name,Organization,Environment,Content View,Host Collections,Virtual,Guest of Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscription Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription Contract,Subscription Account,Subscription Start,Subscription End,Subscription Guest"
      stop_vcr
    end

    # import a single line, testing that subscription is added
    def test_import_single_line
      start_vcr
      set_user 'admin'

      hostname = 'testhypervisor1'

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},Test Corporation,Library,Default Organization View,\"\",Yes,,RHEL 7.2,x86_64,2,3882752,1,\"\",\"69|Red Hat Enterprise Linux Server,290|Red Hat OpenShift Enterprise\",\"\"\"1|RH00001|Red Hat Enterprise Linux for Virtual Datacenters, Premium\"\"\"\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal "Creating content host '#{hostname}'...done\n", stdout

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      lines.select! { |line| line.match(/testhypervisor1.*/) }
      assert_equal 1, lines.length
      assert_match(/.*Test Corporation,Library,Default Organization View,"",Yes,,RHEL 7.2,x86_64,2,3882752,1.*/, lines[0])
      assert_match(/.*1|RH00001|Red Hat Enterprise Linux for Virtual Datacenters, Premium.*/, lines[0])
      host_delete(hostname)

      stop_vcr
    end

    def test_import_search
      start_vcr
      set_user 'admin'

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("testaaa%d,2,Test Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,2,4 GB,4,Standard,\"69|Red Hat Enterprise Linux Server\",\n")
      file.write("testbbb%d,3,Test Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,4,16 GB,8,Premium,\"69|Red Hat Enterprise Linux Server\",\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr

      file = Tempfile.new('content_hosts_test')
      file.write("Search,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("name ~ testaaa,Test Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,2,4 GB,4,Standard,\"69|Red Hat Enterprise Linux Server\",\"\"\"2|RH00004|Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)|10999113|5700573\"\"\"\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal "Updating content host 'testaaa0'...done\nUpdating content host 'testaaa1'...done\n", stdout


      %w{testaaa0 testaaa1 testbbb0 testbbb1 testbbb2}.each do |hostname|
        host_delete(hostname)
      end

      stop_vcr
    end

    def test_columns_config
      start_vcr
      set_user 'admin'

      config_modify({
                     :"content-hosts" => {
                       :define => [{
                                     :name => "Subscription Status",
                                     :json => %w(subscription_status_label)
                                   },
                                   {
                                     :name => "Last Checkin",
                                     :json => %w(subscription_facet_attributes last_checkin)
                                   }],
                       :export => [
                         "Name",
                         "Organization",
                         "Subscription Status"
                       ]
                     }})
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal "Name,Organization,Subscription Status", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal "testphysical,Test Corporation,Fully entitled", lines[0]

      stop_vcr
    ensure
      config_restore
    end

    def test_columns_config_options
      start_vcr
      set_user 'admin'

      config_modify({
                     :"content-hosts" => {
                       :define => [{
                                     :name => "Subscription Status",
                                     :json => %w(subscription_status_label)
                                   },
                                   {
                                     :name => "Last Checkin",
                                     :json => %w(subscription_facet_attributes last_checkin)
                                   }],
                       :export => [
                         "Name",
                         "Organization",
                         "Subscription Status"
                       ]
                     }})

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal "Name,Organization,Subscription Status", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal "testphysical,Test Corporation,Fully entitled", lines[0]

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation --columns Name,Organization,Environment,Subscription\ Status})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal "Name,Organization,Environment,Subscription Status", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal "testphysical,Test Corporation,Library,Fully entitled", lines[0]

      stop_vcr
    ensure
      config_restore
    end

    def test_columns_options
      start_vcr
      set_user 'admin'

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("testcolopts%d,2,Test Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,2,4 GB,4,Standard,\"69|Red Hat Enterprise Linux Server\",\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --export --organization Test\ Corporation --columns Name,Organization,Subscription\ Status,Environment})
      }
      assert_equal "Warning: Column 'Subscription Status' does not match any field, be sure to check spelling. A full list of supported columns are available with 'hammer csv content-hosts --help'\n", stderr
      lines = stdout.split("\n")
      assert_equal "Name,Organization,Subscription Status,Environment", lines[0]
      fields = lines[1].split(",")
      assert_equal 4, fields.length
      assert_equal "", fields[2]  # Subscription Status not defined in this test so blank
      assert_equal "Library", fields[3]

      %w{testcolopts0 testcolopts1}.each do |hostname|
        host_delete(hostname)
      end

      stop_vcr
    end

    def test_itemized_columns_options
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --itemized-subscriptions --export --organization Test\ Corporation --columns Name,Subscription\ Status,Subscription\ Name,Subscription\ Quantity,Subscription\ SKU})
      }
      assert_equal "Warning: Column 'Subscription Status' does not match any field, be sure to check spelling. A full list of supported columns are available with 'hammer csv content-hosts --help'\n", stderr
      lines = stdout.split("\n")
      assert_equal "Name,Subscription Status,Subscription Name,Subscription Quantity,Subscription SKU", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal 'testphysical,,"Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)",1,RH00004', lines[0]

      stop_vcr
    end

    def test_itemized_columns_config_options
      start_vcr
      set_user 'admin'
      config_modify({
                     :"content-hosts" => {
                       :define => [{
                                     :name => "Subscription Status",
                                     :json => %w(subscription_status_label)
                                   },
                                   {
                                     :name => "Last Checkin",
                                     :json => %w(subscription_facet_attributes last_checkin)
                                   }],
                       :export => [
                         "Name",
                         "Subscription Status",
                         "Subscription Name",
                         "Subscription Quantity"
                       ]
                     }})

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --itemized-subscriptions --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal "Name,Subscription Status,Subscription Name,Subscription Quantity", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal "testphysical,Fully entitled,\"Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)\",1", lines[0]

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --itemized-subscriptions --export --organization Test\ Corporation --columns Name,Subscription\ Status,Subscription\ Name,Subscription\ Quantity,Subscription\ SKU})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal "Name,Subscription Status,Subscription Name,Subscription Quantity,Subscription SKU", lines[0]
      lines.select! { |line| line.match(/testphysical.*/) }
      assert_equal 1, lines.length
      assert_equal "testphysical,Fully entitled,\"Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)\",1,RH00004", lines[0]

      stop_vcr
    ensure
      config_restore
    end

    def config_modify(columns)
      config = HammerCLI::Settings.dump
      config[:csv][:columns] = columns
      # HammerCLI::Settings.clear
      # config_file = Tempfile.new('content_hosts_test')
      # FileUtils.cp(File.dirname(__FILE__) + "/../config.yml", config_file.path)
      # config_file.seek(0, IO::SEEK_END)
      # config_file.write settings
      # config_file.rewind
      # HammerCLI::Settings.load_from_file config_file.path
    end

    def config_restore
      config = HammerCLI::Settings.dump
      config[:csv].delete(:columns)
      # HammerCLI::Settings.load_from_file(File.dirname(__FILE__) + "/../config.yml")
    end
  end
end
# rubocop:enable LineLength
