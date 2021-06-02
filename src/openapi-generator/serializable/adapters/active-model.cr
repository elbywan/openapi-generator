require "open_api"
require "../serializable"
require "../../extensions"
require "active-model"

module OpenAPI::Generator::Serializable::Adapters::ActiveModel
  {% unless (@type == OpenAPI::Generator::Serializable::Adapters::ActiveModel || @type.ancestors.includes?(::ActiveModel::Model)) %}
    {% raise AdapterError.new("ActiveModel::Model was not inherited for type {{@type}}") %}
  {% end %}

  # Serialize the class into an `OpenAPI::Schema` representation.
  #
  # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
  def generate_schema
    schema = OpenAPI::Schema.new(
      type: "object",
      properties: Hash(String, (OpenAPI::Schema | OpenAPI::Reference)).new,
      required: [] of String
    )

    {% for name, opts in @type.constant("FIELDS") %}
      ::OpenAPI::Generator::Serializable::Utils.generate_schema(
        schema,
        types: {{opts[:klass].resolve.union_types}},
        schema_key: {{name.id}},
        read_only: {{!opts["mass_assign"]}},
        write_only: {{opts["tags"] && opts["tags"]["write_only"]}},
        example: {{opts["tags"] && opts["tags"]["example"]}}
      )
    {% end %}

    if schema.required.try &.empty?
      schema.required = nil
    end

    schema
  end
end
