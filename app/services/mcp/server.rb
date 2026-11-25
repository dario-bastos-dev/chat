# Model Context Protocol server over JSON-RPC 2.0. It answers one message per HTTP request and never
# opens a stream, which the Streamable HTTP transport allows for servers that only answer requests.
class Mcp::Server
  PROTOCOL_VERSIONS = %w[2025-06-18 2025-03-26 2024-11-05].freeze
  INSTRUCTIONS = 'Tools to read and manage the conversations, contacts, messages and labels of one Chatwoot account. ' \
                 'Conversations are identified by their display id, the number shown in the dashboard.'.freeze

  def self.error_response(id, code, message)
    { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
  end

  def initialize(runner:, read_only:)
    @runner = runner
    @read_only = read_only
  end

  # Returns the JSON-RPC response, or nil when the message is a notification or a response and needs no reply.
  def handle(message)
    raise Mcp::ProtocolError.new(Mcp::ProtocolError::INVALID_REQUEST, 'Invalid Request') unless message.is_a?(Hash) && message['jsonrpc'] == '2.0'
    return unless request?(message)

    { jsonrpc: '2.0', id: message['id'], result: dispatch(message['method'], message.fetch('params', {})) }
  rescue Mcp::ProtocolError => e
    self.class.error_response(message.is_a?(Hash) ? message['id'] : nil, e.code, e.message)
  end

  private

  attr_reader :runner, :read_only

  def request?(message)
    message['method'].is_a?(String) && !message['id'].nil?
  end

  def dispatch(method, params)
    raise Mcp::ProtocolError.new(Mcp::ProtocolError::INVALID_PARAMS, 'Params must be an object') unless params.is_a?(Hash)

    case method
    when 'initialize' then initialize_result(params)
    when 'ping' then {}
    when 'tools/list' then { tools: available_tools.map(&:definition) }
    when 'tools/call' then call_tool(params)
    else raise Mcp::ProtocolError.new(Mcp::ProtocolError::METHOD_NOT_FOUND, "Method not found: #{method}")
    end
  end

  def initialize_result(params)
    requested_version = params['protocolVersion']
    {
      protocolVersion: PROTOCOL_VERSIONS.include?(requested_version) ? requested_version : PROTOCOL_VERSIONS.first,
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: 'chatwoot', version: Chatwoot.config[:version].to_s },
      instructions: INSTRUCTIONS
    }
  end

  def available_tools
    read_only ? Mcp::ToolCatalog.tools.select(&:read_only?) : Mcp::ToolCatalog.tools
  end

  def call_tool(params)
    tool = Mcp::ToolCatalog.find(params['name'])
    raise Mcp::ProtocolError.new(Mcp::ProtocolError::INVALID_PARAMS, "Unknown tool: #{params['name']}") if tool.nil?
    return tool_result("#{tool.name} is not available while the MCP server is in read-only mode", error: true) unless available_tools.include?(tool)

    arguments = params.fetch('arguments', {})
    raise Mcp::ProtocolError.new(Mcp::ProtocolError::INVALID_PARAMS, 'Arguments must be an object') unless arguments.is_a?(Hash)

    result = runner.call(tool, arguments)
    tool_result(result.text, error: result.error)
  rescue Mcp::InvalidArguments => e
    tool_result(e.message, error: true)
  end

  def tool_result(text, error:)
    { content: [{ type: 'text', text: text }], isError: error }
  end
end
