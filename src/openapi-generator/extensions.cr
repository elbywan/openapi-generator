# :nodoc:
# Define a `self.to_openapi_schema` method for the Array class.
class Array(T)
  # Converts an Array to an OpenAPI schema.
  def self.to_openapi_schema
    schema_items = uninitialized OpenAPI::Schema | OpenAPI::Reference

    {% begin %}
      {% array_types = T.union_types %}

      ::OpenAPI::Generator::Serializable.generate_schema(
        schema_items,
        types: {{array_types}},
      )
    {% end %}

    OpenAPI::Schema.new(
      type: "array",
      items: schema_items
    )
  end
end

# :nodoc:
# Define a `self.to_openapi_schema` method for the Hash class.
class Hash(K, V)
  # Returns the OpenAPI schema associated with the Hash.
  def self.to_openapi_schema
    additional_properties = uninitialized (OpenAPI::Schema | OpenAPI::Reference | Bool)?

    {% begin %}
      {% value_types = V.union_types %}

      ::OpenAPI::Generator::Serializable.generate_schema(
        additional_properties,
        types: {{value_types}},
      )
    {% end %}

    OpenAPI::Schema.new(
      type: "object",
      additional_properties: additional_properties
    )
  end
end

# :nodoc:
# Define a `self.to_openapi_schema` method for the NamedTuple class.
struct NamedTuple
  # Returns the OpenAPI schema associated with the NamedTuple.
  def self.to_openapi_schema
    schema = OpenAPI::Schema.new(
      type: "object",
      properties: Hash(String, (OpenAPI::Schema | OpenAPI::Reference)).new,
      required: [] of String
    )

    {% begin %}
      {% for key, value in T %}
        {% types = value.union_types %}
        ::OpenAPI::Generator::Serializable.generate_schema(
          schema,
          types: {{types}},
          schema_key: {{key}}
        )
      {% end %}
    {% end %}

    schema
  end
end

# :nodoc:
class String
  # :nodoc:
  def self.to_openapi_schema
    OpenAPI::Schema.new(
      type: "string"
    )
  end
end

module OpenAPI
  # :nodoc:
  # Used to declare path parameters.
  struct Operation
    setter parameters
  end

  # :nodoc:
  class Schema
    setter read_only
    setter write_only
  end

  # :nodoc:
  struct Response
    setter content
  end
end
