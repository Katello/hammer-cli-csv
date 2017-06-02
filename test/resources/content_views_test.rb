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
      refute_equal '', stderr
      assert_equal stdout[0..-2], "Creating content view '#{name}'...done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-views --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating content view '#{name}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache content-view list --search name=#{name}))
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n").length, 5
      content_view_delete(name)

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
  end
end
# rubocop:enable LineLength
