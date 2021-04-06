require "json"
require "file_utils"
require "action-controller"
require "../spec_helper"
require "../../src/openapi-generator/helpers/action-controller"

class Payload
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@mandatory : String, @optional : Bool?, @with_default : String, @with_default_nillable : String?)
  end
end

class HelloPayloadActionController < ActionController::Base
  include ::OpenAPI::Generator::Controller
  include ::OpenAPI::Generator::Helpers::ActionController

  base "/hello"

  @[OpenAPI(
    <<-YAML
      summary: Sends a hello payload
      responses:
        200:
          description: Overriden
    YAML
  )]
  def create
    mandatory = param mandatory : String, "A mandatory query parameter"
    optional = param optional : Bool?, "An optional query parameter"
    with_default = param with_default : String = "default_value", "A mandatory query parameter with default"
    with_default_nillable = param with_default_nillable : String? = "default_value_nillable", "An optional query parameter with default"

    body_as Payload?, description: "A Hello payload."

    payload = Payload.new(mandatory, optional, with_default, with_default_nillable)
    respond_with 200, description: "Hello" do
      json payload, type: Payload
      xml "<hello></hello>", type: String
    end
    respond_with 201, description: "Not Overriden" do
      text "Good morning.", type: String
    end
    respond_with 400 do
      text "Ouch.", schema: String.to_openapi_schema
    end
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
    openapi_file_contents.should eq <<-YAML
    ---
    openapi: 3.0.1
    info:
      title: Test
      version: 0.0.1
    paths:
      /hello:
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
                  - $ref: '#/components/schemas/Payload'
            required: false
          responses:
            "200":
              description: Hello
              content:
                application/json:
                  schema:
                    allOf:
                    - $ref: '#/components/schemas/Payload'
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
    components:
      schemas:
        Model:
          required:
          - string
          - inner_schema
          - cast
          type: object
          properties:
            string:
              type: string
            opt_string:
              type: string
              readOnly: true
            inner_schema:
              $ref: '#/components/schemas/Model_InnerModel'
            cast:
              type: string
              example: "1"
        Model_InnerModel:
          required:
          - array_of_int
          type: object
          properties:
            array_of_int:
              type: array
              items:
                type: integer
              writeOnly: true
        Model_ComplexModel:
          required:
          - union_types
          - free_form
          - array_of_hash
          type: object
          properties:
            union_types:
              oneOf:
              - type: object
                additionalProperties:
                  $ref: '#/components/schemas/Model_InnerModel'
              - type: integer
              - type: string
            free_form:
              type: object
              additionalProperties: true
            array_of_hash:
              type: array
              items:
                type: object
                additionalProperties:
                  oneOf:
                  - type: integer
                  - type: string
        Payload:
          required:
          - mandatory
          - with_default
          type: object
          properties:
            mandatory:
              type: string
            optional:
              type: boolean
            with_default:
              type: string
            with_default_nillable:
              type: string
      responses: {}
      parameters: {}
      examples: {}
      requestBodies: {}
      headers: {}
      securitySchemes: {}
      links: {}
      callbacks: {}

    YAML
  end

  it "should deserialise mandatory" do
    res = HelloPayloadActionController.context(
      method: "GET", route: "/hello",
      route_params: {"mandatory" => "man"},
      headers: {"Content-Type" => "application/json"}, &.create)

    expected_body = Payload.new("man", nil, "default_value", "default_value_nillable")

    res.status_code.should eq(200)
    res.output.to_s.should eq(expected_body.to_json)
  end

  it "should set defaults" do
    res = HelloPayloadActionController.context(
      method: "GET", route: "/hello",
      route_params: {
        "mandatory"             => "man",
        "optional"              => "true",
        "with_default"          => "not_default",
        "with_default_nillable" => "value",
      },
      headers: {"Content-Type" => "application/json"}, &.create)

    expected_body = Payload.new("man", true, "not_default", "value")

    res.status_code.should eq(200)
    res.output.to_s.should eq(expected_body.to_json)
  end

  it "should raise if there is no mandatory param" do
    expect_raises(KeyError) do
      HelloPayloadActionController.context(method: "GET", route: "/hello", headers: {"Content-Type" => "application/json"}, &.create)
    end
  end
end
