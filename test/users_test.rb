require File.join(File.dirname(__FILE__), 'csv_test_helper')

require 'stringio'
require 'tempfile'

describe 'users' do

  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'
  end

  context "import" do

    it "hammer -v csv:users --csv-file tempfile" do
      file = Tempfile.new('users_test')
      file.write(
<<-eos
Name,Count,First Name,Last Name,Email,Organizations,Locations,Roles
damon.dials@megacorp.com,1,Damon,Dials,damon.dials@megacorp.com,Mega Corporation,,
eos
                   )
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv users -v --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal 'Updating user \'damon.dials@megacorp.com\'... done'
      file.unlink
    end

  end
end
