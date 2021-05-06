require "./utils"

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

  # Including allows overloading.
  macro included
    macro extended
    {% verbatim do %}
    # When the including subclass is extended, add the subtype to the global list.
    {% OpenAPI::Generator::Serializable::SERIALIZABLE_CLASSES << @type %}
    {% end %}
    end
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
      {% schema_key = json_ann && json_ann[:key] && json_ann[:key].id || ivar.id %}
      {% as_type = openapi_ann && openapi_ann[:type] && openapi_ann[:type].types.map(&.resolve) %}
      {% read_only = openapi_ann && openapi_ann[:read_only] %}
      {% write_only = openapi_ann && openapi_ann[:write_only] %}
      {% example = openapi_ann && openapi_ann[:example] %}

      {% unless json_ann && json_ann[:ignore] %}
        ::OpenAPI::Generator::Serializable::Utils.generate_schema(
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

    if schema.required.try &.empty?
      schema.required = nil
    end

    schema
  end

  # Serialize the class into an `OpenAPI::Reference` representation.
  #
  # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
  def to_openapi_schema
    OpenAPI::Schema.new(
      all_of: [
        OpenAPI::Reference.new ref: "#/components/schemas/#{URI.encode_www_form({{@type.stringify.split("::").join("_")}})}",
      ]
    )
  end

  # :nodoc:
  def self.schemas
    # For every registered class, we get its schema and store it in the schemas.
    schemas = Hash(String, OpenAPI::Schema | OpenAPI::Reference).new
    {% for serializable_class in SERIALIZABLE_CLASSES %}
      # Forbid namespace seperator "::" in type name due to being YAML-illegal in plain style (YAML 1.2 - 7.3.3)
      schemas[{{serializable_class.id.split("::").join("_")}}] = {{serializable_class}}.generate_schema
    {% end %}
    # And we return the list of schemas.
    schemas
  end
end
