require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupContentViews < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{csv content-views --verbose --file test/data/setup/content-views.csv})
      }
      assert_equal stderr, ''

      stop_vcr
    end
  end
end
