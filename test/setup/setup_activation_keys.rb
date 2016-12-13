require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupActivationKeys < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys.csv})
      }
      assert_equal stderr, ''

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv activation-keys --verbose --file test/data/setup/activation-keys-itemized.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
