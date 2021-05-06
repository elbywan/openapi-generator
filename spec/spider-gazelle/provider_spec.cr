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
    route_mappings = provider.route_mappings.sort { |a, b|
      comparison = a[0] <=> b[0]
      comparison == 0 ? a[1] <=> b[1] : comparison
    }
    # helper_spec file + this file
    route_mappings.should eq [
      {"get", "/hello", "HelperSpecActionController::index", [] of String},
      {"get", "/{id}", "ProviderSpecActionController::show", ["id"]},
      {"post", "/hello", "HelperSpecActionController::create", [] of String},
    ]
  end
end
