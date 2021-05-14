require "../spec_helper"
require "lucky"

class LuckyProviderSpec::Index < Lucky::Action
  default_format :text

  get "/:id" do
    plain_text "hello world"
  end
end

require "../../src/openapi-generator/providers/lucky.cr"

describe OpenAPI::Generator::RoutesProvider::Lucky do
  it "should correctly detect routes and map them with the controller method" do
    provider = OpenAPI::Generator::RoutesProvider::Lucky.new
    route_mappings = provider.route_mappings.sort { |a, b|
      comparison = a[0] <=> b[0]
      comparison == 0 ? a[1] <=> b[1] : comparison
    }
    # from the helper spec file + this spec file
    route_mappings.should eq [
      {"get", "/{id}", "LuckyProviderSpec::Index", ["id"]},
      {"post", "/hello", "LuckyHelperSpec::Index", [] of String},
    ]
  end
end
