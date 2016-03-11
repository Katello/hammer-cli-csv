require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'job-templates' do

  extend CommandTestHelper

  context "import" do
    it "update settings w/ Count column" do
      set_user 'admin'

      name = "settings#{rand(10000)}"

      file = Tempfile.new('settings_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Count,Value
idle_timeout,1,60000
FILE
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv settings --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      lines[0].must_equal "Updating setting 'idle_timeout'...done"
      file.unlink
    end
  end
end
