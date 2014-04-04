require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'organizations' do

  extend CommandTestHelper

  before :each do
    HammerCLI::Settings.load_from_file 'test/config.yml'

    @api = ApipieBindings::API.new({
                                     :uri => HammerCLI::Settings.get(:csv, :host),
                                     :username => HammerCLI::Settings.get(:csv, :username),
                                     :password => HammerCLI::Settings.get(:csv, :password),
                                     :api_version => 2
                                   })

  end

  context "organizations CRUD" do

    it "create, update, delete" do

      name = "host#{rand(10000)}"

      # Create organization
      file = Tempfile.new('organizations_test')
      file.write("Name,Count,Org Label,Description\n")
      file.write("#{name},1,#{name},A test organization\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv organizations -v --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating organization '#{name}'... done"
      file.unlink

      # Update organization
      file = Tempfile.new('organizations_test')
      file.write("Name,Count,Org Label,Description\n")
      file.write("#{name},1,#{name},An updated test organization\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv organizations -v --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Updating organization '#{name}'... done"
      file.unlink

      # Verify organization
      organization = @api.resource(:organizations).call(:index, {
                                              'search' => "name=\"#{name}\""
                                            })['results']
      organization.wont_be_nil
      organization.wont_be_empty
      organization[0]['name'].must_equal name

      # Clean up
      @api.resource(:organizations).call(:destroy, {
                                              'id' => organization[0]['id']
                                             })

      # Verify organization
      organization = @api.resource(:organizations).call(:index, {
                                              'search' => "name=\"#{name}\""
                                            })['results']
      organization.wont_be_nil
      organization.will_be_empty

    end

  end
end
