require "../spec_helper"
require "amber"

class AmberProviderSpecController < Amber::Controller::Base
  include OpenAPI::Generator::Controller

  @[OpenAPI(
    <<-YAML
      summary: Says hello
      responses:
        200:
          description: OK
    YAML
  )]
  def index
    "hello world"
  end
end

Amber::Server.configure do
  routes :api do
    get "/:id", AmberProviderSpecController, :index
  end
end

require "../../src/openapi-generator/providers/amber.cr"

describe OpenAPI::Generator::RoutesProvider::Amber do
  it "should correctly detect routes and map them with the controller method" do
    provider = OpenAPI::Generator::RoutesProvider::Amber.new
    route_mappings = provider.route_mappings.sort { |a, b|
      comparison = a[0] <=> b[0]
      comparison == 0 ? a[1] <=> b[1] : comparison
    }
    # from the helper spec file + this spec file
    route_mappings.should eq [
      {"get", "/{id}", "AmberProviderSpecController::index", ["id"]},
      {"head", "/{id}", "AmberProviderSpecController::index", ["id"]},
      {"options", "/{id}", "AmberProviderSpecController::index", ["id"]},
      {"post", "/hello", "AmberHelperSpecController::index", [] of String},
    ]
  end
end
