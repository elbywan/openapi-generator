require "./spec_helper.cr"

describe OpenAPI::Generator::Serializable do
  it "should serialize an object into an openapi schema" do
    json_schema = ::Model.to_schema.to_pretty_json
    json_schema.should eq ::Model::SCHEMA

    inner_schema = ::Model::InnerModel.to_schema.to_pretty_json
    inner_schema.should eq ::Model::InnerModel::SCHEMA
  end

  it "should serialize a complex object into an openapi schema" do
    json_schema = ::Model::ComplexModel.to_schema.to_pretty_json
    json_schema.should eq ::Model::ComplexModel::SCHEMA
  end
end
