require "action-controller"
require "../spec_helper"

class ProviderSpecActionController < ActionController::Base
  include OpenAPI::Generator::Controller

  base "/"

  getter hello : String { set_hello }

  @[OpenAPI(
    <<-YAML
      summary: Says hello
      responses:
        200:
          description: OK
    YAML
  )]

  def show
    "hello world"
  end

  def set_hello
    params["id"].to_s
  end
end

require "../../src/openapi-generator/providers/action-controller.cr"

describe OpenAPI::Generator::RoutesProvider::ActionController do
  it "should correctly detect routes and map them with the controller method" do
    provider = OpenAPI::Generator::RoutesProvider::ActionController.new
    route_mappings = provider.route_mappings
    route_mappings.should eq [
      # from the helper_spec file
      {"get", "/hello", "HelperSpecActionController::index", [] of String},
      {"post", "/hello", "HelperSpecActionController::create", [] of String},
      # from this spec file
      {"get", "/{id}", "ProviderSpecActionController::show", ["id"]},
    ]
  end
end
