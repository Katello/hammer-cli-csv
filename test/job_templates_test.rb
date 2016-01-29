require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'job-templates' do

  extend CommandTestHelper

  context "import" do
    it "create job template with input" do
      set_user 'admin'

      name = "jobtemplate#{rand(10000)}"

      file = Tempfile.new('job_templates_test')
      # rubocop:disable LineLength
      file.write <<-FILE
"Name","Organizations","Locations","Description","Job Category","Provider","Snippet","Template","Input:Name","Input:Description","Input:Required","Input:Type","Input:Parameters"
"#{name}","","","","TEST","SSH","No","<%= input(""command"") %>"
"#{name}","","","","","","","","command","command to run","Yes","user",""
FILE
      # rubocop:enable LineLength
      file.rewind
      stdout,stderr = capture {
        hammer.run(%W{csv job-templates --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      lines[0].must_equal "Creating job template '#{name}'...done"
      lines[1].must_equal "Creating job template input 'command' on '#{name}'...done"
      file.unlink
    end
  end
end
