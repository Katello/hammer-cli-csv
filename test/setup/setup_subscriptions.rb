require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Setup
  class SetupSubscriptions < MiniTest::Unit::TestCase
    def test_setup
      start_vcr

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv subscriptions --export --organization Test\ Corporation})
      }
      assert_equal stderr, ''
      assert_equal 5, stdout.split("\n").length
      assert_match(/.*"Red Hat Enterprise Linux for Virtual Datacenters, Premium",1,RH00001.*/, stdout)
      assert_match(/.*"Red Hat Enterprise Linux for Virtual Datacenters, Standard",1,RH00002.*/, stdout)

      stop_vcr
    end
  end
end
