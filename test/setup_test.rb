require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'setup' do

  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context 'Setup Organizations' do
    it "hammer -v csv:organizations --csv-file test/data/organizations.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:organizations --csv-file test/data/organizations.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*organization 'Mega Corporation'.*/
    end
  end

  context 'Setup Locations' do
    it "hammer -v csv:locations --csv-file test/data/locations.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:locations --csv-file test/data/locations.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*Asia Pacific.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:operatingsystems --csv-file test/data/operatingsystems.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:operatingsystems --csv-file test/data/operatingsystems.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*operating system 'Fedora 18'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:architectures --csv-file test/data/architectures.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:architectures --csv-file test/data/architectures.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*architecture 'x86_64'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:partitiontables --csv-file test/data/partitiontables.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:partitiontables --csv-file test/data/partitiontables.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*ptable 'ext4 default'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:domains --csv-file test/data/domains.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:domains --csv-file test/data/domains.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*domain 'megacorp.com'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:puppetenvironments --csv-file test/data/puppetenvironments.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:puppetenvironments --csv-file test/data/puppetenvironments.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*environment 'Development'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:hosts --csv-file test/data/hosts.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:hosts --csv-file test/data/hosts.csv})
      }
      stderr.must_equal ''
      stdout.split("\n").length.must_equal 255
      stdout.must_match /.*host 'dhcp129-000\.megacorp\.com'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:puppetfacts --csv-file test/data/puppetfacts.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:puppetfacts --csv-file test/data/puppetfacts.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*puppetfacts 'dhcp129-000.megacorp.com'.*/
    end
  end

  context 'subscription setup' do
    it "hammer -v subscription upload --organization-id megacorp --file test/data/megacorp.zip" do
      # TODO: http://projects.theforeman.org/issues/4748
      "".must_equal "TODO: Bug #4748 - errors on import manifest should complete dynflow task and display information to user"
      stdout,stderr = capture {
        hammer.run(%W{-v subscription upload --organization-id megacorp --file test/data/megacorp.zip})
      }
      stderr.must_equal ''
      stdout.must_match '.*Manifest is being uploaded.*'
    end
  end

  context 'Setup' do
    it "hammer -v csv:products --csv-file test/data/products.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:products --csv-file test/data/products.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*product 'Point of Sale'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:lifecycleenv --csv-file test/data/lifecycleenvironments.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:lifecycleenv --csv-file test/data/lifecycleenvironments.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*environment 'Development'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:systemgroups --csv-file test/data/systemgroups.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:systemgroups --csv-file test/data/systemgroups.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*system group 'Mega Corp HQ'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:systems --csv-file test/data/systems.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:systems --csv-file test/data/systems.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*system 'host0'.*/
    end
  end

  context 'Setup' do
    it "hammer -v csv:activationkeys --csv-file test/data/activationkeys.csv" do
      stdout,stderr = capture {
        hammer.run(%W{-v csv:activationkeys --csv-file test/data/activationkeys.csv})
      }
      stderr.must_equal ''
      stdout.must_match /.*activation key 'damon\.dials@megacorp\.com'.*/
    end
  end

end
