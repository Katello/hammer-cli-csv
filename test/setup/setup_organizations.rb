require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupOrganizations < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{csv organizations --verbose --file test/data/setup/organizations.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
