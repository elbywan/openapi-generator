require "../spec_helper.cr"

describe OpenAPI::Generator::Serializable do
  it "should serialize an object into an openapi schema" do
    json_schema = ::Model.generate_schema.to_pretty_json
    json_schema.should eq ::Model::SCHEMA

    inner_schema = ::Model::InnerModel.generate_schema.to_pretty_json
    inner_schema.should eq ::Model::InnerModel::SCHEMA
  end

  it "should serialize a complex object into an openapi schema" do
    json_schema = ::Model::ComplexModel.generate_schema.to_pretty_json
    json_schema.should eq ::Model::ComplexModel::SCHEMA
  end

  it "should allow includes to make custom adapters" do
    json_schema = ::Model::CustomModel.generate_schema.to_pretty_json
    json_schema.should eq ::Model::CustomModel::SCHEMA
  end
end
