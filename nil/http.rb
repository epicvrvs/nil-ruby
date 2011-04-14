require 'cgi'
require 'net/http'
require 'uri'

module Nil
  class HTTP
    attr_accessor :ssl
    def initialize(server, cookies = {})
      @http = nil
      @cookies = cookies
      @ssl = false
      @port = nil
      @server = server
    end

    def setHeaders
      cookieArray = []
      @cookies.each do |key, value|
        value = CGI.escape(value)
        cookieArray << "#{key}=#{value}"
      end

      cookieString = cookieArray.join('; ')

      @headers =
        {
        'User-Agent' => 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-us,en;q=0.5',
        #'Accept-Encoding' => 'gzip,deflate',
        'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
        'Cookie' => cookieString
      }

      #puts "Cookies used: #{cookieString.inspect}"
    end

    def httpInitialisation
      if @http == nil
        if @ssl
          defaultPort = 443
        else
          defaultPort = 80
        end
        @port = defaultPort if @port == nil
        @http = Net::HTTP.new(@server, @port)
        if @ssl
          @http.use_ssl = true
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
      setHeaders
    end

    def get(path)
      httpInitialisation

      begin
        response = @http.request_get(path, @headers)
        processResponse(response)
        return response.body
      rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError, SocketError => exception
        puts "GET exception: #{exception.inspect}"
        return nil
      end
    end

    def getPostData(input)
      data = input.map do |key, value|
        escapedValue = URI.escape(value)
        "#{key}=#{escapedValue}"
      end
      postData = data.join '&'
      return postData
    end

    def processResponse(response)
      setCookie = response.header['set-cookie']
      if setCookie != nil
        match = setCookie.match(/^(.+?)=(.+?);/)
        if match == nil
          raise "Invalid Set-Cookie field: #{setCookie.inspect}"
        end
        name = match[1]
        value = CGI.unescape(match[2])
        @cookies[name] = value
        #puts "Added a new cookie: #{name.inspect} => #{value.inspect}"
      end
    end

    def post(path, input)
      httpInitialisation

      postData = getPostData(input)
      begin
        @http.request_post(path, postData, @headers) do |response|
          #puts "Location: #{response.header['location'].inspect}"
          #puts "Set-Cookie: #{response.header['set-cookie'].inspect}"
          processResponse(response)
          response.value
          return response.read_body
        end
      rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError, SocketError => exception
        puts "POST exception: #{exception.inspect}"
        return nil
      end
    end

    def redirectPost(path, input)
      httpInitialisation
      postData = getPostData(input)
      response, body = @http.post(path, postData, @headers)
      puts response.class
      puts response.methods.inspect
      return body
    end
  end

  def self.httpDownload(url, cookieHash = {})
    pattern = /(.+?):\/\/([^\/]+)(\/.+)/
    match = pattern.match(url)
    if match == nil
      raise 'Invalid URL specified'
    end
    protocol = match[1]
    server = match[2]
    path = match[3]
    case protocol
    when 'http'
    when 'https'
      client.ssl = true
    else
      raise 'Unsupported protocol'
    end
    client = HTTP.new(server, cookieHash)
    return client.get(path)
  end
end
