require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'import' do
  extend CommandTestHelper

  context "help" do
    it "displays supported options" do
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv import --help})
      }
      stderr.must_equal ''
      stdout.must_equal <<-HELP
Usage:
     csv import [OPTIONS]

Options:
 --dir DIRECTORY               directory to import from
 --organization ORGANIZATION   Only process organization matching this name
 --settings FILE               csv file for settings
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
    end
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
