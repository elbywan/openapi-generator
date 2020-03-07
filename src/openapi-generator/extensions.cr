# Define a to_openapi method for Arrays.
class Array(T)
  # Converts an Array to an OpenAPI schema.
  def self.to_openapi
    {% begin %}

      {% array_types = T.union_types %}
      {% serialized_types = [] of {String, (TypeNode | ArrayLiteral(TypeNode))?} %}

      # For every type parameter of the Array…
      {% for type in array_types %}
        # Serialize the type into an OpenAPI representation.
        # Also store extra data for objects and arrays.
        {% if type <= Union(String, Char) %}
          {% serialized_types << {"string", Nil} %}
        {% elsif type <= Union(Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64) %}
          {% serialized_types << {"integer", Nil} %}
        {% elsif type <= Union(Float32, Float64) %}
          {% serialized_types << {"number", Nil} %}
        {% elsif type == Bool %}
          {% serialized_types << {"boolean", Nil} %}
        {% elsif type <= Array %}
          {% serialized_types << {"array", type.type_vars[0]} %}
        {% elsif OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES.includes? type %}
          {% serialized_types << {"object", type} %}
        {% elsif (type.has_method? :to_schema) || (type.class.has_method? :to_schema) %}
          {% serialized_types << {"self_schema", type} %}
        {% elsif type <= JSON::Any %}
          {% serialized_types << {"json", Nil} %}
        {% else %}
          {% # Ignore other types.
  %}
        {% end %}
      {% end %}

      {% if serialized_types.size == 1 %}
        # As there is only one supported type…
        items = nil
        ref = nil
        generated_schema = nil
        additional_properties = nil

        {% serialized_type = serialized_types[0] %}
        {% type = serialized_type[0] %}
        {% extra = serialized_type[1] %}

        {% if type == "object" %}
          # Store a reference to another object.
          type = nil
          ref = OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
        {% elsif type == "self_schema" %}
          type = nil
          generated_schema = {{extra}}.to_schema
        {% elsif type == "array" %}
          type = "array"
          # Recursively compute array items.
          items = Array({{ extra }}).to_openapi
        {% elsif type == "json" %}
          # Free form object
          type = "object"
          additional_properties = true
        {% else %}
          # This is a basic type.
          type = {{type}}
        {% end %}

        if type
          OpenAPI::Schema.new(
            type: type,
            items: items,
            additional_properties: additional_properties
          )
        elsif generated_schema
          generated_schema
        elsif ref
          ref
        end

      {% elsif serialized_types.size > 1 %}
        # There are multiple supported types, so we create a "oneOf" array…
        one_of = [] of OpenAPI::Schema | OpenAPI::Reference

        {% for serialized_type in serialized_types %}
          {% type = serialized_type[0] %}
          {% extra = serialized_type[1] %}

          items = nil
          ref = nil
          generated_schema = nil
          additional_properties = nil

          {% if type == "object" %}
            # Store a reference to another object.
            type = nil
            ref = OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
          {% elsif type == "self_schema" %}
            type = nil
            generated_schema = {{extra}}.to_schema
          {% elsif type == "array" %}
            type = "array"
            # Recursively compute array items.
            items = Array({{ extra }}).to_openapi
          {% elsif type == "json" %}
            # Free form object
            type = "object"
            additional_properties = true
          {% else %}
            # This is a basic type.
            type = {{type}}
          {% end %}

          # We append the reference, or schema to the "oneOf" array.
          if type
            one_of << OpenAPI::Schema.new(
              type: type,
              items: items,
              additional_properties: additional_properties
            )
          elsif generated_schema
           one_of << generated_schema
          elsif ref
            one_of << ref
          end
        {% end %}

        OpenAPI::Schema.new(one_of: one_of)
      {% end %}

    {% end %}
  end
end

# Define a to_schema method for Arrays.
class Hash(K, V)
  # Returns the OpenAPI schema associated with the Hash.
  def self.to_schema
    additional_properties = uninitialized (OpenAPI::Schema | OpenAPI::Reference)?

    {% begin %}
      {% value_types = V.union_types %}
      {% serialized_types = [] of {String, (TypeNode | ArrayLiteral(TypeNode))?} %}

      # For every value type of the Hash…
      {% for type in value_types %}
        # Serialize the type into an OpenAPI representation.
        # Also store extra data for objects and arrays.
        {% if type <= Union(String, Char) %}
          {% serialized_types << {"string", Nil} %}
        {% elsif type <= Union(Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64) %}
          {% serialized_types << {"integer", Nil} %}
        {% elsif type <= Union(Float32, Float64) %}
          {% serialized_types << {"number", Nil} %}
        {% elsif type == Bool %}
          {% serialized_types << {"boolean", Nil} %}
        {% elsif type <= Array %}
          {% serialized_types << {"array", type.type_vars[0]} %}
        {% elsif OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES.includes? type %}
          {% serialized_types << {"object", type} %}
        {% elsif (type.has_method? :to_schema) || (type.class.has_method? :to_schema) %}
          {% serialized_types << {"self_schema", type} %}
        {% elsif type <= JSON::Any %}
          {% serialized_types << {"json", Nil} %}
        {% else %}
          {% # Ignore other types.

  %}
        {% end %}
      {% end %}

      {% if serialized_types.size == 1 %}
        # As there is only one supported type…
        items = nil
        ref = nil
        generated_schema = nil
        additional_properties = nil

        {% serialized_type = serialized_types[0] %}
        {% type = serialized_type[0] %}
        {% extra = serialized_type[1] %}

        {% if type == "object" %}
          # Store a reference to another object.
          type = nil
          ref = OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
        {% elsif type == "self_schema" %}
          type = nil
          generated_schema = {{extra}}.to_schema
        {% elsif type == "array" %}
          type = "array"
          # Recursively compute array items.
          items = Array({{ extra }}).to_openapi
        {% elsif type == "json" %}
          # Free form object
          type = "object"
          additional_properties = true
        {% else %}
          # This is a basic type.
          type = {{type}}
        {% end %}

        if type
          additional_properties = OpenAPI::Schema.new(
            type: type,
            items: items,
            additional_properties: additional_properties
          )
        elsif generated_schema
          additional_properties << generated_schema
        elsif ref
          additional_properties = ref
        end

      {% elsif serialized_types.size > 1 %}
        # There are multiple supported types, so we create a "oneOf" array…
        one_of = [] of OpenAPI::Schema | OpenAPI::Reference

        {% for serialized_type in serialized_types %}
          {% type = serialized_type[0] %}
          {% extra = serialized_type[1] %}

          items = nil
          ref = nil
          generated_schema = nil
          additional_properties = nil

          {% if type == "object" %}
            # Store a reference to another object.
            type = nil
            ref = OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
          {% elsif type == "self_schema" %}
            type = nil
            generated_schema = {{extra}}.to_schema
          {% elsif type == "array" %}
            type = "array"
            # Recursively compute array items.
            items = Array({{ extra }}).to_openapi
          {% elsif type == "json" %}
            # Free form object
            type = "object"
            additional_properties = true
          {% else %}
            # This is a basic type.
            type = {{type}}
          {% end %}

          # We append the reference, or schema to the "oneOf" array.
          if type
            one_of << OpenAPI::Schema.new(
              type: type,
              items: items,
              additional_properties: additional_properties
            )
          elsif generated_schema
            one_of << generated_schema
          elsif ref
            one_of << ref
          end
        {% end %}

        additional_properties = OpenAPI::Schema.new(one_of: one_of)
      {% end %}
    {% end %}

    OpenAPI::Schema.new(
      type: "object",
      additional_properties: additional_properties
    )
  end
end

module OpenAPI
  # Used to declare path parameters.
  struct Operation
    setter parameters
  end
end
