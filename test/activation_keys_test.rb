require File.join(File.dirname(__FILE__), 'csv_test_helper')
require File.join(File.dirname(__FILE__), 'apipie_resource_mock')


describe HammerCLICsv::ActivationKeysCommand do

  extend CommandTestHelper

  before :each do
    @activationkey_api = ApipieResourceMock.new(KatelloApi::Resources::ActivationKey)
    @organization_api = ApipieResourceMock.new(KatelloApi::Resources::Organization)
    @environment_api = ApipieResourceMock.new(KatelloApi::Resources::Environment)
    @contentview_api = ApipieResourceMock.new(KatelloApi::Resources::ContentView)
  end

  context "ActivationKeysCommand" do

    let(:cmd) { HammerCLICsv::ActivationKeysCommand.new("", ctx) }

    context "parameters" do
      it "blah" do
        cmd.stubs(:get_lines).returns([
                                       "Name,Count,Org Label,Description,Limit,Environment,Content View,System Groups",
                                       "'akey',1,'org','some description','Unlimited','Library','Default_Content_view',"
                                      ])
        cmd.run(['--csv-file=some_file', '--threads=1']).must_equal HammerCLI::EX_OK
      end
    end
  end
end
