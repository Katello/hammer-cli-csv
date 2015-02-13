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
        hammer.run(%W{csv content-hosts --verbose --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating content host '#{hostname}'...done\nUpdating hypervisor and guest associations...done"
      file.unlink

      # Update system
      file = Tempfile.new('systems_test')
      file.write("Name,Count,Organization,Environment,Content View,System Groups,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{hostname},1,Mega Corporation,Library,Default Organization View,Mega Corp HQ,No,,RHEL 6.4,x86_64,1,8,1,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Updating content host '#{hostname}'...done\nUpdating hypervisor and guest associations...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W{organization list --search megacorp})
      }
      stdout.split("\n").length.must_equal 5
      organization_id = stdout.split("\n")[3].split('|')[0].to_i

      # Verify system
      system = api.resource(:systems).call(:index, {
                                              'organization_id' => organization_id,
                                              'search' => hostname
                                            })['results']
      system.wont_be_nil
      system.wont_be_empty
      system[0]['name'].must_equal hostname

      # Clean up
      api.resource(:systems).call(:destroy, {
                                             'id' => system[0]['id']
                                            })
    end

  end
end
