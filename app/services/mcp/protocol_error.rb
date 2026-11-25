class Mcp::ProtocolError < StandardError
  PARSE_ERROR = -32_700
  INVALID_REQUEST = -32_600
  METHOD_NOT_FOUND = -32_601
  INVALID_PARAMS = -32_602

  attr_reader :code

  def initialize(code, message)
    super(message)
    @code = code
  end
end
