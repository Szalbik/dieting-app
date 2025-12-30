# frozen_string_literal: true

require 'json-schema'

class DietJsonValidationError < StandardError
  attr_reader :errors

  def initialize(message, errors = [])
    super(message)
    @errors = errors
  end
end

class DietJsonValidator
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'diet_parser_schema.json').freeze

  def self.validate!(json_data)
    new.validate!(json_data)
  end

  def self.validate(json_data)
    new.validate(json_data)
  end

  def initialize
    @schema = load_schema
  end

  def validate!(json_data)
    result = validate(json_data)
    return json_data if result[:valid]

    error_messages = result[:errors].map { |e| format_error(e) }
    raise DietJsonValidationError.new(
      "Diet JSON validation failed: #{error_messages.join('; ')}",
      result[:errors]
    )
  end

  def validate(json_data)
    # Use validate_schema: false to skip meta-schema validation
    # This avoids the need to register draft-07 meta-schema
    errors = JSON::Validator.fully_validate(@schema, json_data, strict: true, validate_schema: false)
    {
      valid: errors.empty?,
      errors: errors
    }
  rescue JSON::Schema::SchemaError => e
    # If we still get schema errors, try removing $schema field
    schema_without_meta = @schema.dup
    schema_without_meta.delete('$schema')
    
    errors = JSON::Validator.fully_validate(schema_without_meta, json_data, strict: true, validate_schema: false)
    {
      valid: errors.empty?,
      errors: errors
    }
  end

  private

  def load_schema
    @loaded_schema ||= JSON.parse(File.read(SCHEMA_PATH))
  end

  def format_error(error)
    # JSON::Validator.fully_validate returns an array of error strings
    error.to_s
  end
end

