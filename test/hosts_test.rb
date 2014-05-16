require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'setup' do

  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context 'Test hosts from setup' do

    it "hammer -v --csv host list --search=name=dhcp129-000.megacorp.com" do
      stdout,stderr = capture {
        hammer.run(%W{-v --csv host list --search=name=dhcp129-000.megacorp.com})
      }
      stderr.must_equal ''
      stdout.split("\n").length.must_equal 2
      stdout.must_match /.*dhcp129-000\.megacorp\.com.*/

      host_id = stdout.split("\n")[1].split(",")[0]
    end

    let(:host_id) {
      stdout,stderr = capture {
        hammer.run(%W{-v --csv host list --search=name=dhcp129-000.megacorp.com})
      }
      host_id = stdout.split("\n")[1].split(",")[0]
    }

    it "hammer -v host info --id $id" do
      stdout,stderr = capture {
        hammer.run(%W{-v host info --id #{host_id}})
      }
      stderr.must_equal ''
      attributes = {}
      stdout.split("\n").each do |line|
        name,value = line.split(":")
        attributes[name.strip] = (value.nil? ? '' : value.strip)
      end
      attributes['Id'].must_equal host_id
      attributes['Name'].must_equal 'dhcp129-000.megacorp.com'

    end
  end

end
