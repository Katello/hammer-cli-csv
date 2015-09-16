require File.join(File.dirname(__FILE__), 'csv_test_helper')

require 'stringio'
require 'tempfile'

describe 'users' do
  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context "--dir" do
    it "hammer csv import --verbose --dir does-not-exist" do
      stdout,stderr = capture {
        hammer.run(%W{--debug csv import --verbose --dir does-not-exist})
      }
      stderr.must_equal ''
      stdout.must_equal(
<<-eos
Skipping settings because 'does-not-exist/settings.csv' does not exist
Skipping organizations because 'does-not-exist/organizations.csv' does not exist
Skipping locations because 'does-not-exist/locations.csv' does not exist
Skipping puppet_environments because 'does-not-exist/puppet-environments.csv' does not exist
Skipping operating_systems because 'does-not-exist/operating-systems.csv' does not exist
Skipping domains because 'does-not-exist/domains.csv' does not exist
Skipping architectures because 'does-not-exist/architectures.csv' does not exist
Skipping partition_tables because 'does-not-exist/partition-tables.csv' does not exist
Skipping lifecycle_environments because 'does-not-exist/lifecycle-environments.csv' does not exist
Skipping host_collections because 'does-not-exist/host-collections.csv' does not exist
Skipping provisioning_templates because 'does-not-exist/provisioning-templates.csv' does not exist
Skipping subscriptions because 'does-not-exist/subscriptions.csv' does not exist
Skipping products because 'does-not-exist/products.csv' does not exist
Skipping content_views because 'does-not-exist/content-views.csv' does not exist
Skipping content_view_filters because 'does-not-exist/content-view_filters.csv' does not exist
Skipping activation_keys because 'does-not-exist/activation-keys.csv' does not exist
Skipping hosts because 'does-not-exist/hosts.csv' does not exist
Skipping content_hosts because 'does-not-exist/content-hosts.csv' does not exist
Skipping reports because 'does-not-exist/reports.csv' does not exist
Skipping roles because 'does-not-exist/roles.csv' does not exist
Skipping users because 'does-not-exist/users.csv' does not exist
eos
)
    end

    it "hammer csv import --verbose --organizations does-not-exist.csv" do
      stdout,stderr = capture {
        hammer.run(%W{csv import --verbose --organizations does-not-exist.csv})
      }
      stdout.must_equal ''
      stderr[0..-2].must_equal 'Error: File for organizations \'does-not-exist.csv\' does not exist'
    end

    it "hammer csv import --verbose --organization unknown-org --organizations test/data/organizations.csv" do
      stdout,stderr = capture {
        hammer.run(%W{csv import --verbose --organization unknown-org --organizations test/data/organizations.csv})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal 'Importing organizations from \'test/data/organizations.csv\''
    end

    it "hammer csv import --verbose --organization unknown-org --organizations test/data/organizations.csv" do
      stdout,stderr = capture {
        hammer.run(%W{csv import --verbose --organization unknown-org --organizations test/data/organizations.csv})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal 'Importing organizations from \'test/data/organizations.csv\''
    end

    it "hammer csv import --verbose --prefix $rand --organizations test/data/organizations.csv" do
      prefix = rand(10000)
      stdout,stderr = capture {
        hammer.run(%W{csv import --verbose --prefix #{prefix} --organizations test/data/organizations.csv})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Importing organizations from 'test/data/organizations.csv'\nCreating organization '#{prefix}Mega Corporation'... done"
    end
  end
end
