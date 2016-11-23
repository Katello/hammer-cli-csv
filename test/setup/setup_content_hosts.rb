require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupContentHosts < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-hosts --verbose --file test/data/setup/content-hosts.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
