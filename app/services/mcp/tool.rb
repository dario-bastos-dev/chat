class Mcp::Tool
  PATH_PARAMETER = /\{(\w+)\}/
  NUMERIC_ID = /\A\d+\z/

  attr_reader :name, :description, :http_method, :path, :body_key

  def initialize(attributes)
    @name = attributes.fetch('name')
    @description = attributes.fetch('description')
    @http_method = attributes.fetch('method').upcase
    @path = attributes.fetch('path')
    @body_key = attributes['body_key']
    @destructive = attributes.fetch('destructive') { !read_only? }
    @open_world = attributes.fetch('open_world', false)
    @parameters = attributes.fetch('parameters', {})
    @required = attributes.fetch('required', [])
  end

  def read_only?
    http_method == 'GET'
  end

  def definition
    {
      name: name,
      description: description,
      inputSchema: input_schema,
      annotations: { readOnlyHint: read_only?, destructiveHint: destructive, openWorldHint: open_world }
    }
  end

  # Endpoint path with the {placeholders} replaced by the numeric arguments.
  def path_for(arguments)
    validate_arguments!(arguments)
    path.gsub(PATH_PARAMETER) { arguments.fetch(Regexp.last_match(1)).to_s }
  end

  # Arguments that are not part of the path, in the shape the endpoint expects.
  def request_arguments(arguments)
    values = arguments.except(*path_parameter_names)
    body_key ? { body_key => values } : values
  end

  private

  attr_reader :parameters, :required, :destructive, :open_world

  def input_schema
    schema = { type: 'object', properties: parameters }
    schema[:required] = required if required.any?
    schema
  end

  def path_parameter_names
    path.scan(PATH_PARAMETER).flatten
  end

  def validate_arguments!(arguments)
    unknown = arguments.keys - parameters.keys
    raise Mcp::InvalidArguments, "Unknown arguments: #{unknown.join(', ')}" if unknown.any?

    missing = required - arguments.keys
    raise Mcp::InvalidArguments, "Missing required arguments: #{missing.join(', ')}" if missing.any?

    invalid = path_parameter_names.reject { |key| arguments[key].to_s.match?(NUMERIC_ID) }
    raise Mcp::InvalidArguments, "Arguments must be numeric ids: #{invalid.join(', ')}" if invalid.any?
  end
end
