if RUBY_VERSION > "2.2"
  # Coverage - Keep these two lines at the top of this file
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter,
                          Coveralls::SimpleCov::Formatter]
  SimpleCov.start do
    minimum_coverage 26
    maximum_coverage_drop 0.1
    refuse_coverage_drop
    track_files "lib/**/*.rb"
    add_filter '/test/'
  end
end

require 'rubygems'
require 'logger'
require 'minitest/unit'
require 'minitest/autorun'
require 'mocha/setup'

require './test/vcr_setup'

begin
  require 'debugger'
rescue LoadError
  puts 'Debugging not enabled.'
end

module MiniTest
  class Unit
    class TestCase
      def cassette_name
        test_name = self.__name__.gsub('test_', '')
        parent = (self.class.name.split('::')[-2] || '').underscore
        self_class = self.class.name.split('::')[-1].underscore.gsub('test_', '')
        "#{parent}/#{self_class}/#{test_name}"
      end

      def start_vcr
        options = self.class.respond_to?(:cassette_options) ? self.class.cassette_options : {}
        VCR.insert_cassette(cassette_name, options)
      end

      def stop_vcr
        VCR.eject_cassette
      end

      class << self
        attr_accessor :support

        def suite_cassette_name
          parent = (self.name.split('::')[-2] || '').underscore
          self_class = self.name.split('::')[-1].underscore.gsub('test_', '')
          "#{parent}/#{self_class}/suite"
        end
      end


    end
  end
end

class CustomMiniTestRunner
  class Unit < MiniTest::Unit
    def before_suites
      # code to run before the first test
    end

    def after_suites
      # code to run after the last test
    end

    def _run_suites(suites, type)
      if ENV['suite']
        suites = suites.select do |suite|
          suite.name == ENV['suite']
        end
      end
      before_suites
      super(suites, type)
    ensure
      after_suites
    end

    def _run_suite(suite, type)
      options = suite.respond_to?(:cassette_options) ? suite.cassette_options : {}
      if logging?
        puts "Running Suite #{suite.inspect} - #{type.inspect} "
      end
      if suite.respond_to?(:before_suite)
        VCR.use_cassette(suite.suite_cassette_name, options) do
          suite.before_suite
        end
      end
      super(suite, type)
    ensure
      if suite.respond_to?(:after_suite)
        VCR.use_cassette(suite.suite_cassette_name, options) do
          suite.after_suite
        end
      end
      if logging?
        puts "Completed Running Suite #{suite.inspect} - #{type.inspect} "
      end
    end

    def logging?
      ENV['logging']
    end
  end
end

class CsvMiniTestRunner
  def run_tests(suite, options = {})
    mode      = options[:mode] || 'none'
    test_name = options[:test_name] || nil
    logging   = options[:logging] || false

    MiniTest::Unit.runner = CustomMiniTestRunner::Unit.new

    vcr_config(mode)

    if test_name && File.exist?(test_name)
      require test_name
    elsif test_name
      require "./test/#{test_name}_test.rb"
    else
      Dir["./test/#{suite}/*_test.rb"].each { |file| require file }
    end
  end

  def vcr_config(mode)
    load_config_settings
    if mode == 'all'
      configure_vcr(:all)
    elsif mode == 'new_episodes'
      configure_vcr(:new_episodes)
    elsif mode == 'once'
      configure_vcr(:once)
    else
      configure_vcr(:none)
    end
  end

  def load_config_settings
    if File.exists? 'test/config.yml'
      HammerCLI::Settings.load_from_file 'test/config.yml'
    else
      HammerCLI::Settings.load({
                                 :ui => {
                                   :interactive => true,
                                   :per_page => 20,
                                   :history_file => './log/history'
                                 },
                                 :watch_plain => true,
                                 :log_dir => './log',
                                 :log_level => 'error',
                                 :log_api_calls => false,
                                 :log_size => 5,
                                 :csv => {
                                   :enable_module => true
                                 },
                                 :foreman => {
                                   :enable_module => true,
                                   :host => 'https://localhost',
                                   :username => 'admin',
                                   :password => 'changeme'
                                 },
                                 :katello => {
                                   :enable_module => true
                                 }
                               })
    end
  end
end
