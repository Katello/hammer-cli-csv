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
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end

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

    def test_itemized_create_and_update
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }

      start_vcr
      set_user 'admin'

      name = "ak1"
      sub_name = "Red Hat Enterprise Linux Server, Premium (8 sockets) (Unlimited guests)"
      quantity = 1

      file = Tempfile.new('activation_keys_test')
      file.write("Name,Organization,Description,Limit,Environment,Content View,Host\
                  Collections,Auto-Attach,Service Level,Release Version,Subscription\
                  Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription\
                  Contract,Subscription Account,Subscription Start,Subscription End\n")
      file.write("#{name},Default Organization,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,#{quantity},RH0105260,10855292,5535485,2016-01-05T05:00:00+00:00,2017-01-05T04:59:59+00:00")

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
      file.write("#{name},Default Organization,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,Automatic,RH0105260,10855292,5535485,2016-01-05T05:00:00+00:00,2017-01-05T04:59:59+00:00")

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
      file.write("#{name},Default Organization,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,,RH0105260,10855292,5535485,2016-01-05T05:00:00+00:00,2017-01-05T04:59:59+00:00")

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
      file.write("#{name},Default Organization,,,,Default Organization View,\"\",Yes,,,\"#{sub_name}\",Red\
                  Hat,\"\",RH0105260,10855292,5535485,2016-01-05T05:00:00+00:00,2017-01-05T04:59:59+00:00")

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
