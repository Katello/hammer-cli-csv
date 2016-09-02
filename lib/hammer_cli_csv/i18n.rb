require 'hammer_cli/i18n'

module HammerCLICsv
  module I18n

    class LocaleDomain < HammerCLI::I18n::LocaleDomain

      def translated_files
        Dir.glob(File.join(File.dirname(__FILE__), '../**/*.rb'))
      end

      def locale_dir
        File.join(File.dirname(__FILE__), '../../locale')
      end

      def domain_name
        'hammer-cli-csv'
      end
    end

  end
end

HammerCLI::I18n.add_domain(HammerCLICsv::I18n::LocaleDomain.new)

FastGettext.add_text_domain('hammer-cli-csv',
                            :path => File.expand_path("../../../locale", __FILE__),
                            :type => :po,
                            :ignore_fuzzy => true,
                            :report_warning => false
                           )
FastGettext.default_text_domain = 'hammer-cli-csv'
