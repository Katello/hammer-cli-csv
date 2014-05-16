require File.join(File.dirname(__FILE__), 'csv_test_helper')
#require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require 'stringio'
require 'tempfile'

describe 'something' do

  extend CommandTestHelper


  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context 'activation keys' do

    # Expected output of the form:
    # ID,Name,Consumed
    # 1,damon.dials@megacorp.com,0 of Unlimited
    it 'allows show' do
      set_user 'damon.dials@megacorp.com'

      stdout,stderr = capture {
        hammer.run(%W{activation-key list --organization-id megacorp}).must_equal HammerCLI::EX_OK
      }
      lines = stdout.split("\n")
      lines.length.must_equal 2
      lines[1].must_match /.*damon.dials@megacorp\.com.*/

      id = lines[1].split(',')[0]
      stdout,stderr = capture {
        hammer.run(%W{activation-key info --id #{id}}).must_equal HammerCLI::EX_OK
      }
      stdout.split("\n")[1].must_match /.*damon.dials@megacorp.com,[0-9]+,Individual account,Library,Default Organization View/
    end

  end

end
