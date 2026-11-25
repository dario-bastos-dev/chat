# Runs a tool by sending the request to the account's REST API with the credentials of the MCP caller,
# so every permission, validation and feature flag of the API applies to the tool as well.
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
      value = request.headers[name]
      env["HTTP_#{name.upcase.tr('-', '_')}"] = value if value.present?
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
