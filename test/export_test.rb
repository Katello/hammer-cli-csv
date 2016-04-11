require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'export' do
  extend CommandTestHelper

  context "help" do
    it "displays supported options" do
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv export --help})
      }
      stderr.must_equal ''
      stdout.must_equal <<-HELP
Usage:
     csv export [OPTIONS]

Options:
 --dir DIRECTORY               directory to export to
 --organization ORGANIZATION   Only process organization matching this name
 --settings FILE               csv file for settings
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
    end
  end
end
