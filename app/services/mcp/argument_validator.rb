# Checks tool arguments against the JSON Schema properties declared in config/mcp_tools.yml, so the model gets
# a message it can act on instead of whatever error the API raises for an unexpected value.
class Mcp::ArgumentValidator
  INTEGER_STRING = /\A-?\d+\z/

  TYPES = {
    'string' => { article: 'a string', valid: ->(value) { value.is_a?(String) } },
    'integer' => { article: 'an integer', valid: ->(value) { value.is_a?(Integer) || value.to_s.match?(INTEGER_STRING) } },
    'boolean' => { article: 'a boolean', valid: ->(value) { [true, false].include?(value) } },
    'array' => { article: 'an array', valid: ->(value) { value.is_a?(Array) } },
    'object' => { article: 'an object', valid: ->(value) { value.is_a?(Hash) } }
  }.freeze

  def initialize(parameters:, required:)
    @parameters = parameters
    @required = required
  end

  # One message per invalid argument, in the order the arguments were sent.
  def errors(arguments)
    arguments.filter_map { |name, value| error_for(name, value) }
  end

  private

  attr_reader :parameters, :required

  def error_for(name, value)
    return ("#{name} must not be null" if required.include?(name)) if value.nil?

    schema = parameters.fetch(name)
    type_error(name, value, schema['type']) ||
      enum_error(name, value, schema['enum']) ||
      minimum_error(name, value, schema['minimum']) ||
      items_error(name, value, schema['items'])
  end

  def type_error(name, value, type)
    return if valid_type?(type, value)

    "#{name} must be #{TYPES.fetch(type)[:article]}"
  end

  def enum_error(name, value, allowed)
    return if allowed.nil? || allowed.include?(value)

    "#{name} must be one of: #{allowed.join(', ')}"
  end

  def minimum_error(name, value, minimum)
    return if minimum.nil? || value.to_i >= minimum

    "#{name} must be at least #{minimum}"
  end

  def items_error(name, value, items)
    return if items.nil? || value.all? { |item| valid_type?(items['type'], item) }

    "#{name} must be an array of #{items['type']}s"
  end

  def valid_type?(type, value)
    TYPES.fetch(type)[:valid].call(value)
  end
end
