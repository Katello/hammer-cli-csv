require './test/csv_test_helper'
require './lib/hammer_cli_csv'

# rubocop:disable LineLength
module Resources
  class TestContentViews < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv content-views [OPTIONS]

Options:
 --[no-]promote                Publish and promote content view on import (default false)
 --[no-]publish                Publish content view on import (default false)
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 --search SEARCH               Only export search results
 -h, --help                    Print help
 -v, --verbose                 Be verbose
HELP
      stop_vcr
    end

    def test_create_and_update
      start_vcr
      set_user 'admin'

      name = "testcv1"

      file = Tempfile.new('content_views_test')
      file.write("Name,Label,Organization,Composite,Repositories or Composites,Lifecycle Environments\n")
      file.write("#{name},#{name},Test Corporation,No,"",Library\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path}})
      }
      assert_equal '', stderr # no task
      assert_equal stdout[0..-2], "Creating content view '#{name}'...\ndone"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path}})
      }
      assert_equal '', stderr # no task
      assert_equal stdout[0..-2], "Updating content view '#{name}'...\ndone"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache content-view list --search name=#{name}))
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n").length, 5
      content_view_delete(name)

      stop_vcr
    end

    def test_import_no_publish
      start_vcr
      set_user 'admin'

      name = "testcv1"

      file = Tempfile.new('content_views_test')
      file.write("Name,Label,Organization,Composite,Repositories or Composites,Lifecycle Environments\n")
      file.write("#{name},#{name},Test Corporation,No,"",Library\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path} --no-publish})
      }
      assert_equal '', stderr # no task
      assert_equal stdout[0..-2], "Creating content view '#{name}'...\ndone"

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache content-view version list --organization-label testcorp --content-view #{name}})
      }
      versions = stdout.split("\n").length - 3
      assert_equal 0, versions

      file.unlink
      content_view_delete(name)
      stop_vcr
    end

    def test_import_publish
      start_vcr
      set_user 'admin'

      name = "testcv1"

      file = Tempfile.new('content_views_test')
      file.write("Name,Label,Organization,Composite,Repositories or Composites,Lifecycle Environments\n")
      file.write("#{name},#{name},Test Corporation,No,"",Library\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path} --publish})
      }
      assert_match(/Task .* running/, stderr)
      assert_equal stdout[0..-2], "Creating content view '#{name}'...\ndone"

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache content-view version list --organization-label testcorp --content-view #{name}})
      }
      versions = stdout.split("\n").length - 4
      assert_equal 1, versions

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache content-view info --organization-label testcorp --name #{name}})
      }
      environment = stdout[/Lifecycle Environments:(.*)Versions/m, 1].strip.split("\n")
      assert_equal 1, environment.length / 2 # environment contains two lines (id and name)
      assert_match(/Library/, environment.last)

      file.unlink
      content_view_delete(name)
      stop_vcr
    end

    def test_import_promote_no_publish
      start_vcr
      set_user 'admin'

      name = "testcv1"

      file = Tempfile.new('content_views_test')
      file.write('')
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path} --promote --no-publish})
      }
      assert_match(/Cannot pass in --promote with --no-publish/, stderr)

      file.unlink
      stop_vcr
    end

    def test_import_promote
      start_vcr
      set_user 'admin'

      name = "testcv1"

      file = Tempfile.new('content_views_test')
      file.write("Name,Label,Organization,Composite,Repositories or Composites,Lifecycle Environments\n")
      file.write("#{name},#{name},Test Corporation,No,"",\"Library,Development\"\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path} --promote})
      }
      assert_match(/Task .* running/, stderr)
      assert_equal stdout[0..-2], "Creating content view '#{name}'...\ndone"

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache content-view version list --organization-label testcorp --content-view #{name}})
      }
      versions = stdout.split("\n").length - 4
      assert_equal 1, versions

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache content-view info --organization-label testcorp --name #{name}})
      }
      environment = stdout[/Lifecycle Environments:(.*)Versions/m, 1].strip.split("\n")
      assert_equal 2, environment.length / 2 # environment contains two lines (id and name)
      assert_match(/Development/, environment.last)

      file.unlink
      content_view_delete(name, "Library,Development")
      stop_vcr
    end

    def test_export
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n")[0], "Name,Label,Organization,Composite,Repositories or Composites,Lifecycle Environments"
      stop_vcr
    end

    def test_export_promote_publish
      start_vcr
      set_user 'admin'

      _, stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --export --organization Test\ Corporation --promote})
      }
      assert_match(/Cannot pass publish or promote options on export/, stderr)

      _, stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --export --organization Test\ Corporation --publish})
      }
      assert_match(/Cannot pass publish or promote options on export/, stderr)

      stop_vcr
    end
  end
end
# rubocop:enable LineLength
