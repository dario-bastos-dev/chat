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
    raise_if_any('Unknown arguments', arguments.keys - parameters.keys)
    raise_if_any('Missing required arguments', required - arguments.keys)
    raise_if_any('Arguments must be numeric ids', path_parameter_names.reject { |key| arguments[key].to_s.match?(NUMERIC_ID) })

    errors = Mcp::ArgumentValidator.new(parameters: parameters, required: required).errors(arguments)
    raise Mcp::InvalidArguments, errors.join('; ') if errors.any?
  end

  def raise_if_any(message, names)
    raise Mcp::InvalidArguments, "#{message}: #{names.join(', ')}" if names.any?
  end
end
