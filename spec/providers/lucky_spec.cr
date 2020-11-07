require "../spec_helper"
require "lucky"

class Hello::Index < Lucky::Action
  default_format :text

  get "/:id" do
    plain_text "hello world"
  end
end

require "../../src/openapi-generator/providers/lucky.cr"

describe OpenAPI::Generator::RoutesProvider::Lucky do
  it "should correctly detect routes and map them with the controller method" do
    provider = OpenAPI::Generator::RoutesProvider::Lucky.new
    route_mappings = provider.route_mappings
    route_mappings.should eq [
      {"get", "/{id}", "Hello::Index", ["id"]},
    ]
  end
end
