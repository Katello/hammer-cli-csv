require File.join(File.dirname(__FILE__), 'csv_test_helper')

describe 'content-hosts' do

  extend CommandTestHelper

  context "import" do
    it "update content host facts" do
      set_user 'admin'

      hostname = "host#{rand(10000)}"

      # Create content host
      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Mega Corporation,Library,Default Organization View,Mega Corp HQ,No,,RHEL 6.4,x86_64,1,4,1,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating content host '#{hostname}'...done"

      # Update system
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Updating content host '#{hostname}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W{organization list --search label=megacorp})
      }
      stdout.split("\n").length.must_equal 5
      organization_id = stdout.split("\n")[3].split('|')[0].to_i

      # Verify host
      host = api.resource(:hosts).call(:index, {
                                              'organization_id' => organization_id,
                                              'search' => "name=#{hostname}"
                                            })['results']
      host.wont_be_nil
      host.wont_be_empty
      host[0]['name'].must_equal hostname

      # Clean up
      api.resource(:hosts).call(:destroy, {
                                            'id' => host[0]['id']
                                          })
    end

  end
end
