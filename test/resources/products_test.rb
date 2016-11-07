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

    def product_delete(name)
      stdout,stderr = capture {
        hammer.run(%W(product list --organization Test\ Corporation --search #{name}))
      }
      lines = stdout.split("\n")
      if lines.length == 5
        id = stdout.split("\n")[3].split(" ")[0]
        stdout,stderr = capture {
          hammer.run(%W(product delete --organization Test\ Corporation --id #{id}))
        }
      end
    end
  end
end
