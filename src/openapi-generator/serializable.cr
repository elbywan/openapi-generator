# Define everything needed to automatically generate OpenAPI schemas for all the classes that include this module.
module OpenAPI::Generator::Serializable
  extend self

  # A Serializable field.
  annotation Field
  end

  # A list of all serializable subclasses.
  SERIALIZABLE_CLASSES = [] of Class

  macro included
    {% verbatim do %}

    # When included, add the subtype to the global list.
    {% SERIALIZABLE_CLASSES << @type %}

    # Serialize the class into an `OpenAPI::Schema` representation.
    #
    # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
    def self.to_schema
      schema = OpenAPI::Schema.new(
        type: "object",
        properties: Hash(String, (OpenAPI::Schema | OpenAPI::Reference)).new,
        required: [] of String
      )

      # For every instance variable in this Class
      {% for ivar in @type.instance_vars %}

        {% json_ann = ivar.annotation(JSON::Field) %}
        {% openapi_ann = ivar.annotation(OpenAPI::Generator::Serializable::Field) %}
        {% schema_key = json_ann && json_ann[:key] || ivar.id %}
        {% as_type = openapi_ann && openapi_ann[:type] && openapi_ann[:type].types.map(&.resolve) %}
        {% read_only = openapi_ann && openapi_ann[:read_only] %}
        {% write_only = openapi_ann && openapi_ann[:write_only] %}

        {% unless json_ann && json_ann[:ignore] %}

          {% ivar_types = ivar.type.union_types %}
          {% serialized_types = [] of {String, Bool} %}

          # For every type of the instance variable (can be a union, like String | Int32)…
          {% for type in (as_type || ivar_types) %}
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
            {% elsif type <= Array %}
              {% serialized_types << {"array", type.type_vars[0]} %}
            {% elsif OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES.includes? type %}
              {% serialized_types << {"object", type} %}
            {% elsif (type.has_method? :to_schema) || (type.class.has_method? :to_schema) %}
              {% serialized_types << {"self_schema", type} %}
            {% elsif type <= JSON::Any %}
              {% serialized_types << {"json"} %}
            {% else %}
              {% # Ignore other types.

  %}
            {% end %}
          {% end %}

          {% if serialized_types.size > 0 && !ivar.type.nilable? %}
            schema.required.not_nil! << {{ schema_key.stringify }}
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
              ref = OpenAPI::Schema.new(
                read_only: {{ read_only }},
                write_only: {{ write_only }},
                all_of: [
                  OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
                ]
              )
            {% elsif type == "array" %}
              type = "array"
              # Recursively compute array items.
              items = Array({{ extra }}).to_openapi
            {% elsif type == "json" %}
              # Free form object
              type = "object"
              additional_properties = true
            {% elsif type == "self_schema" %}
              type = nil
              generated_schema = {{extra}}.to_schema
            {% else %}
              # This is a basic type.
              type = {{type}}
            {% end %}

            if type
              schema.properties.not_nil!["{{schema_key}}"] = OpenAPI::Schema.new(
                type: type,
                items: items,
                additional_properties: additional_properties,
                read_only: {{ read_only }},
                write_only: {{ write_only }}
              )
            elsif generated_schema
              schema.properties.not_nil!["{{schema_key}}"] = generated_schema
            elsif ref
              schema.properties.not_nil!["{{schema_key}}"] = ref
            end

          {% elsif serialized_types.size > 1 %}
            # There are multiple supported types, so we create a "oneOf" array…
            one_of = [] of OpenAPI::Schema | OpenAPI::Reference

            # And for each type…
            {% for serialized_type in serialized_types %}
              {% type = serialized_type[0] %}
              {% extra = serialized_type[1] %}

              items = nil
              ref = nil
              additional_properties = nil
              generated_schema = nil

              {% if type == "object" %}
                # Store a reference to another object.
                type = nil
                # ref = OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
                ref = OpenAPI::Schema.new(
                  read_only: {{ read_only }},
                  write_only: {{ write_only }},
                  all_of: [
                    OpenAPI::Reference.new ref: "#/components/schemas/{{extra}}"
                  ]
                )
              {% elsif type == "array" %}
                type = "array"
                # Recursively compute array items.
                items = Array({{ extra }}).to_openapi
              {% elsif type == "json" %}
                # Free form object
                type = "object"
                additional_properties = true
              {% elsif type == "self_schema" %}
                type = nil
                generated_schema = {{extra}}.to_schema
              {% else %}
                # This is a basic type.
                type = {{type}}
              {% end %}

              # We append the reference, or schema to the "oneOf" array.
              if type
                one_of << OpenAPI::Schema.new(
                  type: type,
                  items: items,
                  additional_properties: additional_properties,
                  read_only: {{ read_only }},
                  write_only: {{ write_only }}
                )
              elsif generated_schema
                one_of << generated_schema
              elsif ref
                one_of << ref
              end
            {% end %}

            schema.properties.not_nil!["{{schema_key}}"] = OpenAPI::Schema.new(one_of: one_of)
          {% end %}
        {% end %}

      {% end %}

      schema
    end
    {% end %}
  end

  def self.schemas
    # For every registered class, we get its schema and store it in the schemas.
    schemas = Hash(String, OpenAPI::Schema | OpenAPI::Reference).new
    {% for serializable_class in SERIALIZABLE_CLASSES %}
      schemas["{{serializable_class.id}}"] = {{serializable_class}}.to_schema
    {% end %}
    # And we return the list of schemas.
    schemas
  end
end
