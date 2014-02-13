require File.join(File.dirname(__FILE__), 'csv_test_helper')
require File.join(File.dirname(__FILE__), 'apipie_resource_mock')


describe HammerCLICsv::ActivationKeysCommand do

  extend CommandTestHelper

  before :each do
  end

  context "ActivationKeysCommand" do

    let(:cmd) { HammerCLICsv::ActivationKeysCommand.new("", ctx) }

  end
end
