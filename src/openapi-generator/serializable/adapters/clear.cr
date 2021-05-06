require "open_api"
require "../serializable"
require "../../extensions"
require "clear"

# Bind a column to the model.
#
# Simple example:
# ```
# class MyModel
#   include Clear::Model
#
#   column some_id : Int32, primary: true
#   column nullable_column : String?
# end
# ```
# options:
#
# * `primary : Bool`: Let Clear ORM know which column is the primary key.
# Currently compound primary key are not compatible with Clear ORM.
#
# * `converter : Class | Module`: Use this class to convert the data from the
# SQL. This class must possess the class methods
# `to_column(::Clear::SQL::Any) : T` and `to_db(T) : ::Clear::SQL::Any`
# with `T` the type of the column.
#
# * `column_name : String`: If the name of the column in the model doesn't fit the name of the
#   column in the SQL, you can use the parameter `column_name` to tell Clear about
#   which db column is linked to current field.
#
# * `presence : Bool (default = true)`: Use this option to let know Clear that
#   your column is not nullable but with default value generated by the database
#   on insert (e.g. serial)
# During validation before saving, the presence will not be checked on this field
#   and Clear will try to insert without the field value.
#
# * `mass_assign : Bool (default = true)`: Use this option to turn on/ off mass assignment
#   when instantiating or updating a new model from json through `.from_json` methods from
#   the `Clear::Model::JSONDeserialize` module.
#
# * `ignore_serialize : Bool (default = true)`: same as `ignore_serialize`: turn on/ off serialization
#   of a field when doing `.to_json` on the model
#
# * `example : String (default = nil)`: Use this option only if you have extended
#   OpenAPI::Generator::Serializable to declare an example for this field
#
module Clear::Model::HasColumns
  macro column(name, primary = false, converter = nil, column_name = nil, presence = true, mass_assign = true, ignore_serialize = false, example = nil)
    {% _type = name.type %}
    {%
      unless converter
        if _type.is_a?(Path)
          if _type.resolve.stringify =~ /\(/
            converter = _type.stringify
          else
            converter = _type.resolve.stringify
          end
        elsif _type.is_a?(Generic) # Union?
          if _type.name.stringify == "::Union"
            converter = (_type.type_vars.map(&.resolve).map(&.stringify).sort.reject { |x| x == "Nil" || x == "::Nil" }.join("")).id.stringify
          else
            converter = _type.resolve.stringify
          end
        elsif _type.is_a?(Union)
          converter = (_type.types.map(&.resolve).map(&.stringify).sort.reject { |x| x == "Nil" || x == "::Nil" }.join("")).id.stringify
        else
          raise "Unknown: #{_type}, #{_type.class}"
        end
      end
    %}

    {%
      db_column_name = column_name == nil ? name.var : column_name.id

      COLUMNS["#{db_column_name.id}"] = {
        type:                  _type,
        primary:               primary,
        converter:             converter,
        db_column_name:        "#{db_column_name.id}",
        crystal_variable_name: name.var,
        presence:              presence,
        mass_assign:           mass_assign,
        ignore_serialize:      ignore_serialize,
        example:               example, # OpenAPI
      }
    %}
  end
end

# The `Serializable` module automatically generates an OpenAPI Operations representation of the class or struct when extended.
#
# ### Example
#
# ```
# class ClearModelExample
#   include Clear::Model
#   extend OpenAPI::Generator::Serializable

#   column id : Int64, primary: true, mass_assign: false, example: "123"
#   column email : String, mass_assign: true, example: "default@gmail.com"
# end
# # => {
# #     "required": [
# #       "id",
# #       "email"
# #     ],
# #     "type": "object",
# #     "properties": {
# #       "id": {
# #         "type": "integer",
# #         "readOnly": true,
# #         "example": "123"
# #       },
# #       "email": {
# #         "type": "string",
# #         "writeOnly": true,
# #         "example": "default@gmail.com"
# #       }
# #     }
# #   }
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
module OpenAPI::Generator::Serializable::Adapters::Clear
  # Serialize the class into an `OpenAPI::Schema` representation.
  #
  # Check the [swagger documentation](https://swagger.io/docs/specification/data-models/) for more details
  def generate_schema
    schema = OpenAPI::Schema.new(
      type: "object",
      properties: Hash(String, (OpenAPI::Schema | OpenAPI::Reference)).new,
      required: [] of String
    )

    {% for name, settings in @type.constant("COLUMNS") %}
      {% types = settings[:type].resolve.union_types %}
      {% schema_key = settings["crystal_variable_name"].id %}
      {% example = settings["example"] %}

      ::OpenAPI::Generator::Serializable::Utils.generate_schema(
        schema,
        types: {{types}},
        schema_key: {{schema_key}},
        read_only: {{!settings["mass_assign"]}},
        write_only: {{settings["ignore_serialize"]}},
        example: {{example}}
      )
    {% end %}

    if schema.required.try &.empty?
      schema.required = nil
    end

    schema
  end
end

abstract struct Clear::Enum
  # :nodoc:
  def self.to_openapi_schema
    OpenAPI::Schema.new(
      title: {{@type.name.id.stringify.split("::").join("_")}},
      type: "string",
      enum: self.authorized_values
    )
  end
end
