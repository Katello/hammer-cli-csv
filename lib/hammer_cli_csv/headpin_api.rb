require 'csv'

module HammerCLICsv
  class HeadpinApi
    def initialize(config)
      @server = config[:server]
      @username = config[:username]
      @password = config[:password]
    end

    def get(name)
      url = "#{@server}/api/#{name}"
      uri = URI(url)
      nethttp = Net::HTTP.new(uri.host, uri.port)
      nethttp.use_ssl = uri.scheme == 'https'
      nethttp.verify_mode = OpenSSL::SSL::VERIFY_NONE
      results = nethttp.start do |http|
        request = Net::HTTP::Get.new uri.request_uri
        request.basic_auth(@username, @password)
        response = http.request(request)
        JSON.parse(response.body)
      end
      results
    end

    def environment(id)
      @environments ||= {}
      environment = @environments[id]
      if environment.nil?
        environment = get("environments/#{id}")
        raise environment['displayMessage'] if environment['displayMessage']
        @environments[id] = environment
      end

      return environment
    end

    def content_view(id)
      @content_views ||= {}
      content_view = @content_views[id]
      if content_view.nil?
        content_view = get("content_views/#{id}")
        raise content_view['displayMessage'] if content_view['displayMessage']
        @content_views[id] = content_view
      end

      return content_view
    end
  end
end
