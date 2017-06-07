require './test/csv_test_helper'
require './lib/hammer_cli_csv'

# rubocop:disable LineLength
module Resources
  class TestContentViewFilters < MiniTest::Unit::TestCase
    CONTENT_VIEW = "Test Puppet Modules"
    ORG = "Test Corporation"

    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-view-filters --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
**** This command is unsupported and is provided as tech preview. ****
Usage:
     csv content-view-filters [OPTIONS]

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

      name = "testfilter1"

      file = Tempfile.new('content_view_filters_test')
      file.write("Name,Content View,Organization,Type,Description,Repositories,Rules\n")
      file.write("#{name},#{CONTENT_VIEW},#{ORG},Exclude Packages,,"",jekyll|=|3.0\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-view-filters --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Creating filter '#{name}' for content view filter '#{CONTENT_VIEW}'....done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-view-filters --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating filter '#{name}' for content view filter '#{CONTENT_VIEW}'....done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache content-view filter list --search name=#{name} --content-view #{CONTENT_VIEW} --organization #{ORG}))
      }
      assert_equal '', stderr
      assert_equal 5, stdout.split("\n").length
      content_view_filter_delete(ORG, CONTENT_VIEW, name)

      stop_vcr
    end

    def test_rule_name_change
      start_vcr
      set_user 'admin'

      name = "testfilter1"

      file = Tempfile.new('content_view_filters_test')
      file.write("Name,Content View,Organization,Type,Description,Repositories,Rules\n")
      file.write("#{name},#{CONTENT_VIEW},#{ORG},Exclude Packages,,"",jekyll|=|3.0\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-view-filters --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Creating filter '#{name}' for content view filter '#{CONTENT_VIEW}'....done"
      file.unlink

      # simulate a change in the rule from jekyll to hyde
      file = Tempfile.new('content_view_filters_test')
      file.write("Name,Content View,Organization,Type,Description,Repositories,Rules\n")
      file.write("#{name},#{CONTENT_VIEW},#{ORG},Exclude Packages,,"",hyde|=|3.0\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{--reload-cache csv content-view-filters --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating filter '#{name}' for content view filter '#{CONTENT_VIEW}'....done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache content-view filter list --search name=#{name} --content-view #{CONTENT_VIEW} --organization #{ORG}))
      }
      lines = stdout.split("\n")
      assert_equal '', stderr
      assert_equal 5, lines.length
      id = lines[3].split(" ")[0]

      stdout,stderr = capture {
        hammer.run(%W(--reload-cache content-view filter rule list --content-view-filter-id #{id}))
      }
      lines = stdout.split("\n")
      assert_equal 5, lines.length
      assert_match(/hyde/, lines[3])

      content_view_filter_delete(ORG, CONTENT_VIEW, name)
      stop_vcr
    end
  end
end
# rubocop:enable LineLength
