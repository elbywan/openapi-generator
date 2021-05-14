require "../../src/openapi-generator/serializable/adapters/active-model"
require "spec"

class ActiveModelUser < ActiveModel::Model
  extend OpenAPI::Generator::Serializable::Adapters::ActiveModel

  attribute name : String, tags: {example: "James"}
  attribute age : UInt32
  attribute email : String? = nil
end

describe OpenAPI::Generator::Serializable::Adapters::ActiveModel do
  it "#generate_schema" do
    ActiveModelUser.generate_schema.to_json.should eq(
      %({"required":["name","age"],"type":"object","properties":{"name":{"type":"string","example":"James"},"age":{"type":"integer"},"email":{"type":"string"}}})
    )
  end
end
