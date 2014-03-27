require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'systems' do

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

  context "import" do

    # TODO: Bug #4922 - system facts not updating via API
    # http://projects.theforeman.org/issues/4922
    it "update system facts" do

      hostname = "host#{rand(10000)}"

      # Create system
      file = Tempfile.new('systems_test')
      file.write("Name,Count,Organization,Environment,Content View,System Groups,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Mega Corporation,Library,Default Organization View,Mega Corp HQ,No,,RHEL 6.4,x86_64,1,4,1,Standard,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{-v csv:systems --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating system '#{hostname}'...done\nUpdating host and guest associations...done"
      file.unlink

      # Update system
      file = Tempfile.new('systems_test')
      file.write("Name,Count,Organization,Environment,Content View,System Groups,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Mega Corporation,Library,Default Organization View,Mega Corp HQ,No,,RHEL 6.4,x86_64,1,8,1,Standard,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{-v csv:systems --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Updating system '#{hostname}'...done\nUpdating host and guest associations...done"
      file.unlink

      # Verify system
      system = @api.resource(:systems).call(:index, {
                                              'organization_id' => 'megacorp',
                                              'search' => "name=\"#{hostname}\""
                                            })['results']
      system.wont_be_nil
      system.wont_be_empty
      system[0]['name'].must_equal hostname

      # Clean up
      # TODO: Bug #4921 - bulk remove systems error "user not set"
      # http://projects.theforeman.org/issues/4921
      @api.resource(:systems).call(:destroy, {
                                              'id' => system[0]['id']
                                             })
    end

  end
end
