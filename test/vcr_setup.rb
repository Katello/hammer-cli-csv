require 'rubygems'
require 'vcr'
require 'hammer_cli'

def configure_vcr(mode = :none)
  if ENV['record'] == 'false' && mode == :none
    fail "Record flag is not applicable for mode 'none', please use with 'mode=all'"
  end

  VCR.configure do |c|
    c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
    c.hook_into :webmock

    if ENV['record'] == 'false' && mode != :none
      server = HammerCLI::Settings.get(:csv, :host) ||
          HammerCLI::Settings.get(:katello, :host) ||
          HammerCLI::Settings.get(:foreman, :host)
      uri = URI.parse(server)
      c.ignore_hosts uri.host
    end

    c.default_cassette_options = {
      :record => mode,
      :match_requests_on => [:method, :path, :params, :body_json],
      :decode_compressed_response => true
    }

    # rubocop:disable HandleExceptions
    begin
      c.register_request_matcher :body_json do |request_1, request_2|
        begin
          json_1 = JSON.parse(request_1.body)
          json_2 = JSON.parse(request_2.body)

          json_1 == json_2
        rescue
          #fallback incase there is a JSON parse error
          request_1.body == request_2.body
        end
      end
    rescue
      #ignore the warning thrown about this matcher already being resgistered
    end

    begin
      c.register_request_matcher :params do |request_1, request_2|
        URI(request_1.uri).query == URI(request_2.uri).query
      end
    rescue
      #ignore the warning thrown about this matcher already being resgistered
    end
    # rubocop:enable HandleExceptions
  end
end
