require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestActivationKeys < MiniTest::Unit::TestCase
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
 --search SEARCH               Only export search results
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end

    def test_create_and_update
      start_vcr
      set_user 'admin'

      @name = "testakey2"

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

      # Cleanup for subsequent test runs
      capture {
        hammer.run(%W{activation-key delete --organization-label testcorp --name #{@name}})
      }

      stop_vcr
    end

    def test_itemized_create_and_update
      start_vcr
      _stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }
      assert_equal '', stderr

      set_user 'admin'

      name = "testakey1"
      sub_name = "Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)"
      quantity = 1

      file = Tempfile.new('activation_keys_test')
      file.write("Name,Organization,Description,Limit,Environment,Content View,Host\
                  Collections,Auto-Attach,Service Level,Release Version,Subscription\
                  Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription\
                  Contract,Subscription Account,Subscription Start,Subscription End\n")
      file.write("#{name},Test Corporation,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,#{quantity},RH00004,,1583473,2016-11-10T05:00:00.000+0000,2017-11-10T04:59:59.000+0000")

      file.rewind

      # Attaching an integer quantity of a subscription
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --itemized-subscriptions --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating subscriptions for activation key '#{name}'... attaching #{quantity} of '#{sub_name}'...done"

      file.rewind

      # Attaching already-attached subscription
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --itemized-subscriptions --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating subscriptions for activation key '#{name}'... '#{sub_name}' already attached...done"

      # Attaching automatic quantity with Automatic in quantity field
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }

      file.rewind

      file.write("Name,Organization,Description,Limit,Environment,Content View,Host\
                  Collections,Auto-Attach,Service Level,Release Version,Subscription\
                  Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription\
                  Contract,Subscription Account,Subscription Start,Subscription End\n")
      file.write("#{name},Test Corporation,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,Automatic,RH00004,,1583473,2016-11-10T05:00:00.000+0000,2017-11-10T04:59:59.000+0000")

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --itemized-subscriptions --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating subscriptions for activation key '#{name}'... attaching -1 of '#{sub_name}'...done"

      # Attaching automatic quantity with nothing in quantity field
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }

      file.rewind

      file.write("Name,Organization,Description,Limit,Environment,Content View,Host\
                  Collections,Auto-Attach,Service Level,Release Version,Subscription\
                  Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription\
                  Contract,Subscription Account,Subscription Start,Subscription End\n")
      file.write("#{name},Test Corporation,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,,RH00004,,1583473,2016-11-10T05:00:00.000+0000,2017-11-10T04:59:59.000+0000")

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --itemized-subscriptions --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating subscriptions for activation key '#{name}'... attaching -1 of '#{sub_name}'...done"

      # Attaching automatic quantity with "" in quantity field
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }

      file.rewind

      file.write("Name,Organization,Description,Limit,Environment,Content View,Host\
                  Collections,Auto-Attach,Service Level,Release Version,Subscription\
                  Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription\
                  Contract,Subscription Account,Subscription Start,Subscription End\n")
      file.write("#{name},Test Corporation,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,\"\",RH00004,,1583473,2016-11-10T05:00:00.000+0000,2017-11-10T04:59:59.000+0000")

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --itemized-subscriptions --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating subscriptions for activation key '#{name}'... attaching -1 of '#{sub_name}'...done"

      file.unlink

      stop_vcr
    end
  end
end
