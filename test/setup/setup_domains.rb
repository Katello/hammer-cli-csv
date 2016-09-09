require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupDomains < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv domains --verbose --file test/data/setup/domains.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
