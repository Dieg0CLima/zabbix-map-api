require "net/http"
require "uri"
require "json"

class Zabbix::Client
  class Error < StandardError; end
  class ApiError < Error; end
  class TransportError < Error; end

  def initialize(connection:, http_client: Net::HTTP)
    @connection = connection
    @http_client = http_client
  end

  def call(method, params = {})
    uri = endpoint_uri
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@connection.api_token}" if @connection.api_token.present?
    request.body = JSON.generate(jsonrpc: "2.0", method:, params:, id: next_id)

    response = @http_client.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body)

    raise TransportError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise ApiError, parsed.fetch("error", {}).fetch("data", parsed["error"].to_s) if parsed["error"].present?

    parsed["result"]
  rescue JSON::ParserError => e
    raise TransportError, "Invalid Zabbix response: #{e.message}"
  rescue StandardError => e
    raise e if e.is_a?(Error)

    raise TransportError, e.message
  end

  private

  def endpoint_uri
    base = @connection.base_url.to_s.sub(%r{/+$}, "")
    URI.parse(base.end_with?("api_jsonrpc.php") ? base : "#{base}/api_jsonrpc.php")
  end

  def next_id
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
