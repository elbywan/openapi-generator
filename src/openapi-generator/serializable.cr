# The `Serializable` module automatically generates an OpenAPI Operations representation of the class or struct when extended.
#
# ### Example
#
# ```
# struct Model
#   extend OpenAPI::Generator::Serializable
#   include JSON::Serializable
#
#   property string : String
#   property opt_string : String?
#   @[OpenAPI::Field(ignore: true)]
#   property ignored : Nil
#   @[OpenAPI::Field(type: String, example: "1")]
#   @cast : Int32
#
#   def cast
#     @cast.to_s
#   end
# end
#
# puts Model.to_openapi_schema.to_pretty_json
# # => {
# #   "required": [
# #     "string",
# #     "cast"
# #   ],
# #   "type": "object",
# #   "properties": {
# #     "string": {
# #       "type": "string"
# #     },
# #     "opt_string": {
# #       "type": "string"
# #     },
# #     "cast": {
# #       "type": "string",
# #       "example": "1"
# #     }
# #   }
# # }
# ```
#
# ### Usage
#
# Extending this module adds a `self.to_openapi_schema` that returns an OpenAPI representation
# inferred from the shape of the class or struct.
#
# The class name is also registered as a global [component schema](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#components-object)
# and will be available for referencing from any `Controller` annotation from a [reference object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#referenceObject).
#
# **See:** `OpenAPI::Generator::Controller::Schema.ref`
#
# NOTE: **Calling `to_openapi_schema` programatically is unnecessary.
# The `Generator` will take care of serialization while producing the openapi yaml file.**
module OpenAPI::Generator::Serializable
  # Mark a field with special properties during serialization.
  #
  # ```
  # @[OpenAPI::Field(ignore: true)] # Ignore the field
  # property ignored_field
  #
  # @[OpenAPI::Field(type: String)] # Enforce a type
  # property str_field : Int32
  #
  # # The example value can be any value of type JSON::Any::Type, meaning a string, numbers, booleans, or an array or a hash of json values.
  # @[OpenAPI::Field(example: "an example value")]
  # property a_field : String
  # ```
  annotation OpenAPI::Field
  end

  # A list of all serializable subclasses.
  SERIALIZABLE_CLASSES = [] of Class

  macro extended
    {% verbatim do %}
    # When extended, add the subtype to the global list.
    {% OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES << @type %}
    {% end %}
  end

  macro generate_schema(schema, types, as_type = nil, read_only = false, write_only = false, schema_key = nil, example = nil)
    {% serialized_types = [] of {String, (TypeNode | ArrayLiteral(TypeNode))?} %}
    {% nilable = types.any? { |t| t.resolve.nilable? } %}

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
            OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify}})}"
          ]
        )
        {% else %}
        %generated_schema = OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify}})}"
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
              OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify}})}"
            ]
          )
          {% else %}
          %generated_schema = OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{extra.stringify}})}"
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

  # Serialize the class into an `OpenAPI::Schema` representation.
  #
  # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
  def generate_schema
    schema = OpenAPI::Schema.new(
      type: "object",
      properties: Hash(String, (OpenAPI::Schema | OpenAPI::Reference)).new,
      required: [] of String
    )

    # For every instance variable in this Class
    {% for ivar in @type.instance_vars %}

      {% json_ann = ivar.annotation(JSON::Field) %}
      {% openapi_ann = ivar.annotation(OpenAPI::Field) %}
      {% types = ivar.type.union_types %}
      {% schema_key = json_ann && json_ann[:key] || ivar.id %}
      {% as_type = openapi_ann && openapi_ann[:type] && openapi_ann[:type].types.map(&.resolve) %}
      {% read_only = openapi_ann && openapi_ann[:read_only] %}
      {% write_only = openapi_ann && openapi_ann[:write_only] %}
      {% example = openapi_ann && openapi_ann[:example] %}

      {% unless json_ann && json_ann[:ignore] %}
        ::OpenAPI::Generator::Serializable.generate_schema(
          schema,
          types: {{types}},
          schema_key: {{schema_key}},
          as_type: {{as_type}},
          read_only: {{read_only}},
          write_only: {{write_only}},
          example: {{example}}
        )
      {% end %}

    {% end %}

    schema
  end

  # Serialize the class into an `OpenAPI::Reference` representation.
  #
  # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
  def to_openapi_schema
    OpenAPI::Schema.new(
      all_of: [
        OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{@type.stringify}})}",
      ]
    )
  end

  # :nodoc:
  def self.schemas
    # For every registered class, we get its schema and store it in the schemas.
    schemas = Hash(String, OpenAPI::Schema | OpenAPI::Reference).new
    {% for serializable_class in SERIALIZABLE_CLASSES %}
      schemas["{{serializable_class.id}}"] = {{serializable_class}}.generate_schema
    {% end %}
    # And we return the list of schemas.
    schemas
  end
end
