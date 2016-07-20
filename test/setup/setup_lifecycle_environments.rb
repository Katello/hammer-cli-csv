require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupLifecycleEnvironments < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{csv lifecycle-environments --verbose --file test/data/setup/lifecycle-environments.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
