require File.join(File.dirname(__FILE__), 'csv_test_helper')

require 'stringio'
require 'tempfile'

describe 'content-views' do
  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context "import" do
    it "hammer csv content-views --verbose --file does-not-exist" do
      stdout,stderr = capture {
        hammer.run(%W{csv content-views --verbose --file does-not-exist})
      }
      stdout.must_equal ''
      stderr[0..-2].must_equal('Error: No such file or directory - does-not-exist')
    end

    it "hammer csv content-views --verbose --file tempfile" do
      contentview = "contentview#{rand(10000)}"
      file = Tempfile.new('content_views_test')
      file.write("Name,Count,Organization,Description,Composite,Repositories,Lifecycle Environments\n")
      file.write("#{contentview},1,Mega Corporation,Katello - The Sysadmin's Fortress,No,Default_Organization_View,Library\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-views --verbose --file #{file.path}})
      }
      stdout[0..-2].must_equal "Creating content view '#{contentview}'...done"

      file.unlink
    end

    it "hammer csv content-views --verbose --file tempfile (no Count column)" do
      contentview = "contentview#{rand(10000)}"
      file = Tempfile.new('content_views_test')
      file.write("Name,Organization,Description,Composite,Repositories,Lifecycle Environments\n")
      file.write("#{contentview},Mega Corporation,Katello - The Sysadmin's Fortress,No,Default_Organization_View,Library\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-views --verbose --file #{file.path}})
      }
      stdout[0..-2].must_equal "Creating content view '#{contentview}'...done"

      file.unlink
    end
  end
end
