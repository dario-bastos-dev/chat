# Runs a tool by sending the request to the account's REST API with the credentials of the MCP caller,
# so every permission, validation and feature flag of the API applies to the tool as well.
#
# The request goes through the whole middleware stack, ActionDispatch::Executor included. That middleware completes
# the execution of the outer request before it starts its own, so once the call returns Current is empty, the query
# cache is cleared and the completion hooks run a second time when the outer request ends. The outer request only
# renders the result, which needs none of that. Database connections are leased per query, so nothing is held across
# the call. Checked without transactional specs on Rails 8.0: 20 threads on a pool of 5 finished with no errors and no
# connection left busy. Re-check that if the outer request ever does more after the tool runs, or if Rails is upgraded.
class Mcp::ToolRunner
  Result = Struct.new(:text, :error)

  # Credentials accepted by the API: personal access tokens and the dashboard session headers.
  AUTH_HEADERS = %w[Authorization api_access_token access-token client uid expiry token-type].freeze

  def initialize(request:, account_id:)
    @request = request
    @account_id = account_id
  end

  def call(tool, arguments)
    path = tool.path_for(arguments)
    status, _headers, body = Rails.application.call(rack_env(tool, path, tool.request_arguments(arguments)))
    Result.new(read_body(body), status >= 400)
  end

  private

  attr_reader :request, :account_id

  def rack_env(tool, path, arguments)
    url = "#{request.base_url}/api/v1/accounts/#{account_id}/#{path}"
    options = forwarded_headers.merge('HTTP_ACCEPT' => 'application/json', 'REMOTE_ADDR' => request.remote_ip)
    options[:method] = tool.http_method

    if tool.read_only?
      url += "?#{Rack::Utils.build_nested_query(arguments)}" if arguments.any?
    else
      options['CONTENT_TYPE'] = 'application/json'
      options[:input] = arguments.to_json
    end

    Rack::MockRequest.env_for(url, options)
  end

  def forwarded_headers
    AUTH_HEADERS.each_with_object({}) do |name, env|
      env_name = "HTTP_#{name.upcase.tr('-', '_')}"
      # Rails only maps names without underscores to HTTP_*, so api_access_token is stored as is by test clients
      # and as HTTP_API_ACCESS_TOKEN when it comes over HTTP. The API accepts both, and so must the forwarding.
      value = request.headers[name].presence || request.env[env_name]
      env[env_name] = value if value.present?
    end
  end

  def read_body(body)
    text = +''
    body.each { |chunk| text << chunk }
    text.force_encoding(Encoding::UTF_8)
  ensure
    body.close if body.respond_to?(:close)
  end
end
