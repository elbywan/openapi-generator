require "json"
require "file_utils"
require "action-controller"
require "../spec_helper"
require "../../src/openapi-generator/helpers/action-controller"

class ActionControllerSpec::Payload
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@mandatory : String, @optional : Bool?, @with_default : String, @with_default_nillable : String?)
  end
end

class HelperSpecActionController < ActionController::Base
  include ::OpenAPI::Generator::Controller
  include ::OpenAPI::Generator::Helpers::ActionController

  base "/hello"

  @[OpenAPI(
    <<-YAML
      summary: get all payloads
    YAML
  )]
  def index
    render json: [ActionControllerSpec::Payload.new("mandatory", true, "default", "nillable")], description: "all payloads", type: Array(ActionControllerSpec::Payload)
  end

  @[OpenAPI(
    <<-YAML
      summary: redirect to index
    YAML
  )]
  def show
    redirect_to("/hello", status: :found, description: "redirect to index res")
  end

  @[OpenAPI(
    <<-YAML
      summary: Sends a hello payload
      responses:
        200:
          description: Overriden
    YAML
  )]
  def create
    mandatory, optional, with_default, with_default_nillable = create_helper

    body_as ActionControllerSpec::Payload?, description: "A Hello payload."

    payload = ActionControllerSpec::Payload.new(mandatory, optional, with_default, with_default_nillable)
    respond_with 200, description: "Hello" do
      json payload, type: ActionControllerSpec::Payload
      xml "<hello></hello>", type: String
    end
    respond_with 201, description: "Not Overriden" do
      text "Good morning.", type: String
    end
    respond_with 400 do
      text "Ouch.", schema: String.to_openapi_schema
    end
  end

  @[OpenAPI(
    <<-YAML
      summary: Destroy route
    YAML
  )]
  def destroy
    head :no_content, description: "No content available"
  end

  get "/custom_route", :custom_route do
    redirect_to("/hello/:id", description: "custom route redirect to show")
  end

  @[OpenAPI(
    <<-YAML
      summary: custom route
    YAML
  )]
  def custom_route
    previous_def
  end

  get "/alt_route" do
    redirect_to("/hello/:id", description: "alternative route redirect to show")
  end

  @[OpenAPI(
    <<-YAML
      summary: alternative route
    YAML
  )]
  def get_alt_route
    previous_def
  end

  private def create_helper
    {
      param(mandatory : String, "A mandatory query parameter"),
      param(optional : Bool?, "An optional query parameter"),
      param(with_default : String = "default_value", "A mandatory query parameter with default"),
      param(with_default_nillable : String? = "default_value_nillable", "An optional query parameter with default"),
    }
  end
end

require "../../src/openapi-generator/providers/action-controller.cr"

OpenAPI::Generator::Helpers::ActionController.bootstrap

describe OpenAPI::Generator::Helpers::ActionController do
  after_all {
    FileUtils.rm "openapi_test.yaml" if File.exists?("openapi_test.yaml")
  }

  it "should infer the status codes and contents of the response body" do
    options = {
      output: Path[Dir.current] / "openapi_test.yaml",
    }
    base_document = {
      info:       {title: "Test", version: "0.0.1"},
      components: NamedTuple.new,
    }

    OpenAPI::Generator.generate(
      OpenAPI::Generator::RoutesProvider::ActionController.new,
      options: options,
      base_document: base_document
    )

    openapi_file_contents = File.read "openapi_test.yaml"
    openapi_file_contents.should eq YAML.parse(<<-YAML
    ---
    openapi: 3.0.1
    info:
      title: Test
      version: 0.0.1
    paths:
      /hello:
        get:
          summary: get all payloads
          responses:
            "200":
              description: all payloads
              content:
                text/yaml:
                  schema:
                    type: array
                    items:
                      $ref: '#/components/schemas/ActionControllerSpec_Payload'
        post:
          summary: Sends a hello payload
          parameters:
          - name: mandatory
            in: query
            description: A mandatory query parameter
            required: true
            schema:
              type: string
          - name: optional
            in: query
            description: An optional query parameter
            required: false
            schema:
              type: boolean
          - name: with_default
            in: query
            description: A mandatory query parameter with default
            required: true
            schema:
              type: string
          - name: with_default_nillable
            in: query
            description: An optional query parameter with default
            required: false
            schema:
              type: string
          requestBody:
            description: A Hello payload.
            content:
              application/json:
                schema:
                  allOf:
                  - $ref: '#/components/schemas/ActionControllerSpec_Payload'
            required: false
          responses:
            "200":
              description: Hello
              content:
                application/json:
                  schema:
                    allOf:
                    - $ref: '#/components/schemas/ActionControllerSpec_Payload'
                application/xml:
                  schema:
                    type: string
            "201":
              description: Not Overriden
              content:
                text/plain:
                  schema:
                    type: string
            "400":
              description: Bad Request
              content:
                text/plain:
                  schema:
                    type: string
      /hello/alt_route:
        get:
          summary: alternative route
          responses:
            "302":
              description: alternative route redirect to show
      /hello/custom_route:
        get:
          summary: custom route
          responses:
            "302":
              description: custom route redirect to show
      /hello/{id}:
        get:
          summary: redirect to index
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          responses:
            "302":
              description: redirect to index res
        delete:
          summary: Destroy route
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          responses:
            "204":
              description: No content available
      /{id}:
        get:
          summary: Says hello
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          responses:
            "200":
              description: OK
    components:
      schemas: {
        #{COMPONENT_SCHEMAS}
        "ActionControllerSpec_Payload": {
          "required": [ "mandatory", "with_default" ],
          "type": "object",
          "properties": {
            "mandatory": {
              "type": "string"
            },
            "optional": {
              "type": "boolean"
            },
            "with_default": {
              "type": "string"
            },
            "with_default_nillable": {
              "type": "string"
            }
          }
        }
      }
      responses: {}
      parameters: {}
      examples: {}
      requestBodies: {}
      headers: {}
      securitySchemes: {}
      links: {}
      callbacks: {}

    YAML
    ).to_yaml
  end

  it "should deserialise mandatory" do
    res = HelperSpecActionController.context(
      method: "POST", route: "/hello",
      route_params: {"mandatory" => "man"},
      headers: {"Content-Type" => "application/json"}, &.create)

    expected_body = ActionControllerSpec::Payload.new("man", nil, "default_value", "default_value_nillable")

    res.status_code.should eq(200)
    res.output.to_s.should eq(expected_body.to_json)
  end

  it "should set defaults" do
    res = HelperSpecActionController.context(
      method: "POST", route: "/hello",
      route_params: {
        "mandatory"             => "man",
        "optional"              => "true",
        "with_default"          => "not_default",
        "with_default_nillable" => "value",
      },
      headers: {"Content-Type" => "application/json"}, &.create)

    expected_body = ActionControllerSpec::Payload.new("man", true, "not_default", "value")

    res.status_code.should eq(200)
    res.output.to_s.should eq(expected_body.to_json)
  end

  it "#head" do
    res = HelperSpecActionController.context(
      method: "DELETE", route: "/hello",
      route_params: {"id" => "example"},
      headers: {"Content-Type" => "application/json"}, &.destroy)

    res.status_code.should eq(204)
    res.output.to_s.should eq("")
  end

  it "#redirect_to" do
    res = HelperSpecActionController.context(
      method: "GET", route: "/hello",
      route_params: {"id" => "example"},
      headers: {"Content-Type" => "application/json"}, &.show)

    res.status_code.should eq(302)
    res.headers["Location"].should eq("/hello")
    res.output.to_s.should be_empty
  end

  it "#custom_route" do
    res = HelperSpecActionController.context(
      method: "GET", route: "/hello/custom_route",
      headers: {"Content-Type" => "application/json"}, &.custom_route)

    res.status_code.should eq(302)
    res.headers["Location"].should eq("/hello/:id")
    res.output.to_s.should be_empty
  end

  it "#custom_route without defining name" do
    res = HelperSpecActionController.context(
      method: "GET", route: "/hello/alt_route",
      headers: {"Content-Type" => "application/json"}, &.get_alt_route)

    res.status_code.should eq(302)
    res.headers["Location"].should eq("/hello/:id")
    res.output.to_s.should be_empty
  end

  it "should raise if there is no mandatory param" do
    expect_raises(HTTP::Params::Serializable::ParamMissingError, "Parameter \"mandatory\" is missing") do
      HelperSpecActionController.context(method: "POST", route: "/hello", headers: {"Content-Type" => "application/json"}, &.create)
    end
  end

  it "should execute macro render" do
    res = HelperSpecActionController.context(method: "GET", route: "/hello", headers: {"Content-Type" => "application/json"}, &.index)

    expected_body = ActionControllerSpec::Payload.new("mandatory", true, "default", "nillable")

    res.status_code.should eq(200)
    res.output.to_s.should eq([expected_body].to_json)
  end
end
