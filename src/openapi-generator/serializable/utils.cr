module OpenAPI::Generator::Serializable::Utils
  macro generate_schema(schema, types, as_type = nil, read_only = false, write_only = false, schema_key = nil, example = nil)
    {% serialized_types = [] of {String, (TypeNode | ArrayLiteral(TypeNode))?} %}
    {% nilable = types.any? &.resolve.nilable? %}

    # For every type of the instance variable (can be a union, like String | Int32)…
    {% for type in (as_type || types) %}
      {% type = type.resolve %}
      # Serialize the type into an OpenAPI representation.
      # Also store extra data for objects and arrays.
      {% if type <= Union(String, Char) %}
        {% serialized_types << {"string"} %}
      {% elsif type <= Union(Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64) %}
        {% serialized_types << {"integer"} %}
      {% elsif type <= Union(Float32, Float64) %}
        {% serialized_types << {"number"} %}
      {% elsif type == Bool %}
        {% serialized_types << {"boolean"} %}
      {% elsif OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES.includes? type %}
        {% serialized_types << {"object", type} %}
      {% elsif type.class.has_method? :to_openapi_schema %}
        {% serialized_types << {"self_schema", type} %}
      {% elsif type <= JSON::Any %}
        {% serialized_types << {"free_form"} %}
      {% else %}
        {% # Ignore other types.

  %}
      {% end %}
    {% end %}

    {% if schema_key && serialized_types.size > 0 && !nilable %}
      {{schema}}.required.not_nil! << {{ schema_key.stringify }}
    {% end %}

    {% if serialized_types.size == 1 %}
      # As there is only one supported type…
      %items = nil
      %generated_schema = nil
      %additional_properties = nil

      {% serialized_type = serialized_types[0] %}
      {% type = serialized_type[0] %}
      {% extra = serialized_type[1] %}

      {% if type == "object" %}
        %type = nil
        # Store a reference to another object.
        {% if read_only || write_only %}
        %generated_schema = OpenAPI::Schema.new(
          read_only: {{ read_only }},
          write_only: {{ write_only }},
          all_of: [
            OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify.split("::").join("_")}})}"
          ]
        )
        {% else %}
        %generated_schema = OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify.split("::").join("_")}})}"
        {% end %}
      {% elsif type == "self_schema" %}
        %type = nil
        %generated_schema = {{extra}}.to_openapi_schema
        {% if read_only %}
        %generated_schema.read_only = true
        {% end %}
        {% if write_only %}
        %generated_schema.write_only = true
        {% end %}
      {% elsif type == "free_form" %}
        # Free form object
        %type = "object"
        %additional_properties = true
      {% else %}
        # This is a basic type.
        %type = {{type}}
      {% end %}

      if %type
        {% if schema_key %}{{schema}}.properties.not_nil!["{{schema_key}}"]{% else %}{{schema}}{% end %} = OpenAPI::Schema.new(
          type: %type,
          items: %items,
          additional_properties: %additional_properties,
          {% if read_only %}  read_only:  {{ read_only }},  {% end %}
          {% if write_only %} write_only: {{ write_only }}, {% end %}
          {% if example != nil %}example: {{ example }},    {% end %}
        )
      elsif %generated_schema
        {% if schema_key %}{{schema}}.properties.not_nil!["{{schema_key}}"]{% else %}{{schema}}{% end %} = %generated_schema
      end

    {% elsif serialized_types.size > 1 %}
      # There are multiple supported types, so we create a "oneOf" array…
      %one_of = [] of OpenAPI::Schema | OpenAPI::Reference

      # And for each type…
      {% for serialized_type in serialized_types %}
        {% type = serialized_type[0] %}
        {% extra = serialized_type[1] %}

        %items = nil
        %additional_properties = nil
        %generated_schema = nil

        {% if type == "object" %}
          %type = nil
          {% if read_only || write_only %}
          %generated_schema = OpenAPI::Schema.new(
            read_only: {{ read_only }},
            write_only: {{ write_only }},
            all_of: [
              OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify.split("::").join("_")}})}"
            ]
          )
          {% else %}
          %generated_schema = OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify.split("::").join("_")}})}"
          {% end %}
        {% elsif type == "self_schema" %}
          %type = nil
          %generated_schema = {{extra}}.to_openapi_schema
          {% if read_only %}
          %generated_schema.read_only = true
          {% end %}
          {% if write_only %}
          %generated_schema.write_only = true
          {% end %}
        {% elsif type == "free_form" %}
          # Free form object
          %type = "object"
          %additional_properties = true
        {% else %}
          # This is a basic type.
          %type = {{type}}
        {% end %}

        # We append the reference, or schema to the "oneOf" array.
        if %type
          %one_of << OpenAPI::Schema.new(
            type: %type,
            items: %items,
            additional_properties: %additional_properties,
            {% if read_only %}  read_only:  {{ read_only }},  {% end %}
            {% if write_only %} write_only: {{ write_only }}, {% end %}
            {% if example != nil %}example: {{ example }},    {% end %}
          )
        elsif %generated_schema
          %one_of << %generated_schema
        end
      {% end %}

      {% if schema_key %}{{schema}}.properties.not_nil!["{{schema_key}}"]{% else %}{{schema}}{% end %} = OpenAPI::Schema.new(one_of: %one_of)
    {% end %}
  end
end
