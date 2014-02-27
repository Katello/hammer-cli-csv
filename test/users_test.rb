require File.join(File.dirname(__FILE__), 'csv_test_helper')
#require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require 'stringio'
require 'tempfile'

describe HammerCLICsv::UsersCommand do

  extend CommandTestHelper

  before :each do
  end

  context 'UsersCommand' do

    let(:cmd) { HammerCLICsv::UsersCommand.new("", ctx) }
    let(:options) {%w{-v -u admin -p changeme --server https://localhost:3000} }

    context "import" do
      it "imports" do
        file = Tempfile.new('users_test')
        file.write(
<<-eos
Name,Count,First Name,Last Name,Email,Organizations,Locations,Roles
damon.dials@megacorp.com,1,Damon,Dials,damon.dials@megacorp.com,Mega Corporation,,damondials
eos
                   )
        file.rewind

        proc {
          cmd.run(options + ['--csv-file', file.path]).must_equal HammerCLI::EX_OK
        }.must_output <<-eos
Updating user 'damon.dials@megacorp.com'... done
eos
        file.unlink
      end
    end

  end
end
