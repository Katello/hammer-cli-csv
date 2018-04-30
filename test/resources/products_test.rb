require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestProducts < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv products [OPTIONS]

Options:
 --[no-]sync                   Sync product repositories (default true)
                               Default: true
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 --search SEARCH               Only export search results
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end

    def test_create_rpm
      start_vcr
      set_user 'admin'
      name = "product create_rpm"

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,Release,Repository Url
#{name},#{name},Test Corporation,,Zoo,Custom Yum,,,https://repos.fedorapeople.org/repos/pulp/pulp/demo_repos/zoo/
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'Zoo'...done", lines[0]
      file.unlink

      product_delete(name)
      stop_vcr
    end

    def test_update_rpm
      start_vcr
      set_user 'admin'
      name = "product update_rpm"

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,Release,Repository Url
#{name},#{name},Test Corporation,,Zoo,Custom Yum,,,https://repos.fedorapeople.org/repos/pulp/pulp/demo_repos/zoo/
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'Zoo'...done", lines[0]

      file.rewind
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Updating product '#{name}'...Updating repository 'Zoo'...done", lines[0]

      file.unlink

      product_delete(name)
      stop_vcr
    end

    def test_create_update_rpm_docker
      start_vcr
      set_user 'admin'
      name = "product create_update_rpm_docker"

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,Release,Repository Url,Verify SSL,Publish via HTTP,Mirror on Sync,Download Policy,Username,Password
#{name},#{name}label,Test Corporation,Yum Product,Zoo,Custom Yum,,,https://repos.fedorapeople.org/repos/pulp/pulp/demo_repos/zoo/,No,No,No,on_demand,,
#{name},#{name}label,Test Corporation,Docker Product,thomasmckay/hammer,Custom Docker,thomasmckay/hammer,,https://registry-1.docker.io/,Yes,Yes,Yes,"",,
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'Zoo'...done", lines[0]
      assert_equal "Updating product '#{name}'...Creating repository 'thomasmckay/hammer'...done", lines[1]

      file.rewind
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Updating product '#{name}'...Updating repository 'Zoo'...done", lines[0]
      assert_equal "Updating product '#{name}'...Updating repository 'thomasmckay/hammer'...done", lines[1]

      file.unlink

      product_delete(name)
      stop_vcr
    end

    def test_create_rhel_release
      start_vcr
      set_user 'admin'

      name = 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7.1'

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,$basearch,$releasever,Repository Url,Verify SSL,Publish via HTTP,Mirror on Sync,Download Policy,Username,Password
Red Hat Enterprise Linux Server,Red_Hat_Enterprise_Linux_Server,Test Corporation,,Red Hat Enterprise Linux 7 Server RPMs x86_64 7.1,Red Hat Yum,Red Hat Enterprise Linux 7 Server (RPMs),,7.1,https://cdn.redhat.com/content/dist/rhel/server/7/7.1/x86_64/os,Yes,No,Yes,on_demand,,
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Enabling repository #{name}...done", lines[0]
      assert_equal "Updating repository '#{name}'...done", lines[1]

      file.rewind
      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Repository #{name} already enabled", lines[0]
      assert_equal "Updating repository '#{name}'...done", lines[1]

      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(repository-set disable --organization Test\ Corporation --product Red\ Hat\ Enterprise\ Linux\ Server --name Red\ Hat\ Enterprise\ Linux\ 7\ Server\ \(RPMs\) --releasever 7.1 --basearch x86_64}))
      }

      stop_vcr
    end

    def test_create_no_label_column
      start_vcr
      set_user 'admin'

      name = 'No Label'

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Organization,Description,Repository,Repository Type,Content Set,$basearch,$releasever,Repository Url,Verify SSL,Publish via HTTP,Mirror on Sync,Download Policy,Username,Password
No Label,Test Corporation,,openshift/origin,Custom Docker,openshift/origin,,,https://registry-1.docker.io,Yes,Yes,Yes,"",,
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'openshift/origin'...done", lines[0]

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache product info --organization Test\ Corporation --name #{name}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Label:        No_Label", lines[2]

      file.unlink

      product_delete(name)
      stop_vcr
    end

    def test_create_empty_label
      start_vcr
      set_user 'admin'

      name = 'EmptyLabel'

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,$basearch,$releasever,Repository Url,Verify SSL,Publish via HTTP,Mirror on Sync,Download Policy,Username,Password
#{name},,Test Corporation,,openshift/origin,Custom Docker,openshift/origin,,,https://registry-1.docker.io,Yes,Yes,Yes,"",,
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'openshift/origin'...done", lines[0]

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache product info --organization Test\ Corporation --name '#{name}'})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Label:        #{name}", lines[2]

      file.unlink

      product_delete(name)
      stop_vcr
    end

    def test_create_with_label
      start_vcr
      set_user 'admin'

      name = 'With Label'

      file = Tempfile.new('products_test')
      # rubocop:disable LineLength
      file.write <<-FILE
Name,Label,Organization,Description,Repository,Repository Type,Content Set,$basearch,$releasever,Repository Url,Verify SSL,Publish via HTTP,Mirror on Sync,Download Policy,Username,Password
With Label,withlabel,Test Corporation,,openshift/origin,Custom Docker,openshift/origin,,,https://registry-1.docker.io,Yes,Yes,Yes,"",,
FILE
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv products --no-sync --verbose --file #{file.path}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Creating product '#{name}'...Creating repository 'openshift/origin'...done", lines[0]

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache product info --organization Test\ Corporation --name #{name}})
      }
      stderr.must_equal ''
      lines = stdout.split("\n")
      assert_equal "Label:        withlabel", lines[2]

      file.unlink

      product_delete(name)
      stop_vcr
    end

    def product_delete(name)
      stdout,stderr = capture {
        hammer.run(%W(product delete --organization Test\ Corporation --name #{name}))
      }
    end
  end
end
