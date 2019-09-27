require 'fieldhand/network_errors'
require 'fieldhand/options'
require 'cgi'
require 'net/http'

module Fieldhand
  # A wrapper around an HTTP client and a URI for optionally retrying failing HTTP requests.
  class Requester
    attr_reader :http, :uri, :logger, :headers, :interval
    attr_accessor :retries

    # Return a new requester with the given HTTP client, URI and optional logger, headers, maximum number of retries and
    # retry interval.
    def initialize(http, uri, options = {})
      @http = http
      @uri = uri

      options = Options.new(options)
      @logger = options.logger
      @headers = options.headers
      @retries = options.retries
      @interval = options.interval
    end

    # Return the response for the request with an optional query, attempting the request multiple times if the maximum
    # number of retries is greater than 0.
    #
    # Will sleep between request attempts according to the instance's retry interval.
    #
    # Raises a `ResponseError` if the request fails more than the permitted number of times.
    def request(query = {})
      response = send_request(query)
      raise ResponseError, response unless response.is_a?(::Net::HTTPSuccess)

      response
    rescue ResponseError => e
      raise e unless retries > 0

      self.retries -= 1
      sleep(interval)

      retry
    end

    private

    def send_request(query = {})
      request_uri = uri.dup
      request_uri.query = encode_query(query)

      logger.info('Fieldhand') { "GET #{request_uri}" }
      http.request(authenticated_request(request_uri.request_uri))
    rescue ::Timeout::Error => e
      raise NetworkError, "timeout requesting #{query}: #{e}"
    rescue => e
      raise NetworkError, "error requesting #{query}: #{e}"
    end

    def encode_query(query = {})
      query.map { |k, v| ::CGI.escape(k) << '=' << ::CGI.escape(v) }.join('&')
    end

    def authenticated_request(uri)
      request = ::Net::HTTP::Get.new(uri)
      headers.each do |key, value|
        request[key] = value
      end

      request
    end
  end
end
