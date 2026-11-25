class Api::V1::Accounts::McpController < Api::V1::Accounts::BaseController
  wrap_parameters false
  before_action :ensure_mcp_server_enabled

  # The server never opens an event stream, so GET is not supported.
  def show
    response.set_header('Allow', 'POST')
    head :method_not_allowed
  end

  def create
    reply = mcp_server.handle(JSON.parse(request.raw_post))
    reply.nil? ? head(:accepted) : render(json: reply)
  rescue JSON::ParserError
    render json: Mcp::Server.error_response(nil, Mcp::ProtocolError::PARSE_ERROR, 'Parse error'), status: :bad_request
  end

  private

  def mcp_server
    runner = Mcp::ToolRunner.new(request: request, account_id: Current.account.id)
    Mcp::Server.new(runner: runner, read_only: read_only?)
  end

  def ensure_mcp_server_enabled
    return if config_enabled?('MCP_SERVER_ENABLED', false)

    render json: { error: 'MCP server is not enabled' }, status: :not_found
  end

  def read_only?
    config_enabled?('MCP_SERVER_READ_ONLY', true)
  end

  # Anything but an explicit false keeps the safer choice, so a missing value never opens writes.
  def config_enabled?(name, default)
    value = ActiveModel::Type::Boolean.new.cast(GlobalConfigService.load(name, default))
    default ? value != false : value == true
  end
end
