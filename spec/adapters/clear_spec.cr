require "../../src/openapi-generator/serializable/adapters/clear"
require "spec"

class ClearModelExample
  include Clear::Model
  extend OpenAPI::Generator::Serializable::Adapters::Clear

  column id : Int64, primary: true, mass_assign: false, example: "123"
  column email : String, write_only: true, example: "default@gmail.com"
end

struct ClearModelExampleCopy
  extend OpenAPI::Generator::Serializable
  include JSON::Serializable

  @[OpenAPI::Field(read_only: true, example: "123")]
  property id : Int64

  @[OpenAPI::Field(write_only: true, example: "default@gmail.com")]
  property email : String
end

describe OpenAPI::Generator::Serializable::Adapters::Clear do
  it "should serialize a Clear Model into an openapi schema" do
    json_schema = ::ClearModelExample.generate_schema.to_pretty_json
    json_schema_copy = ClearModelExampleCopy.generate_schema.to_pretty_json
    json_schema.should eq(json_schema_copy)
  end
end
