require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupLocations < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv locations --verbose --file test/data/setup/locations.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
