require File.join(File.dirname(__FILE__), 'csv_test_helper')
#require File.join(File.dirname(__FILE__), 'apipie_resource_mock')
require 'stringio'
require 'tempfile'

describe 'roles tests' do

  extend CommandTestHelper


  #before :each do
  #  HammerCLI::Settings.load_from_file 'test/config'
  #end

  context 'roles' do

    it 'basic import' do
      set_user 'admin'

      rolename = "role#{rand(10000)}"

      file = Tempfile.new('roles_test')
      file.write("Name,Count,Resource,Search,Permissions,Organizations,Locations\n")
      file.write("#{rolename},1,ActivationKey,name = key_name,view_activation_keys,Mega Corporation,\n")
      file.rewind


      stdout,stderr = capture {
        hammer.run(%W{csv roles --verbose --csv-file #{file.path}})
      }
      stderr.must_equal ''
      stdout[0..-2].must_equal "Creating role '#{rolename}'... creating filter ActivationKey...done"
      file.unlink
    end

    it 'test role functionality' do
      set_user('damon.dials@megacorp.com', 'redhat')

      stdout,stderr = capture {
        hammer.run(%W{activation-key list --organization-label megacorp}).must_equal HammerCLI::EX_OK
      }
      lines = stdout.split("\n")
      lines.length.must_equal 5
      lines[3].must_match /.*damon.dials@megacorp\.com.*/

      id = lines[3].split(' ')[0]
      stdout,stderr = capture {
        hammer.run(%W{activation-key info --id #{id}}).must_equal HammerCLI::EX_OK
      }
      stdout.split("\n")[0].must_match /.*damon.dials@megacorp.com/
    end

  end

end
