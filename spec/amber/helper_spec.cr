require "json"
require "file_utils"
require "amber"
require "../spec_helper"
require "../../src/openapi-generator/helpers/amber"

class AmberSpec::Payload
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@hello : String = "world")
  end
end

class AmberHelperSpecController < Amber::Controller::Base
  include ::OpenAPI::Generator::Controller
  include ::OpenAPI::Generator::Helpers::Amber

  @[OpenAPI(
    <<-YAML
      summary: Sends a hello payload
      responses:
        200:
          description: Overriden
    YAML
  )]
  def index
    _mandatory, _optional = index_helper
    body_as AmberSpec::Payload?, description: "A Hello payload."

    payload = AmberSpec::Payload.new
    respond_with 200, description: "Hello" do
      json payload, type: AmberSpec::Payload
      xml "<hello></hello>", type: String
    end
    respond_with 201, description: "Not Overriden" do
      text "Good morning.", type: String
    end
    respond_with 400 do
      text "Ouch.", schema: String.to_openapi_schema
    end
  end

  @[OpenAPI(dependencies: { index })]
  private def index_helper
    {
      query_params("mandatory", description: "A mandatory query parameter"),
      query_params?("optional", description: "An optional query parameter"),
    }
  end
end

Amber::Server.configure do
  routes :api do
    route "post", "/hello", AmberHelperSpecController, :index
  end
end

require "../../src/openapi-generator/providers/amber.cr"

OpenAPI::Generator::Helpers::Amber.bootstrap

describe OpenAPI::Generator::Helpers::Amber do
  after_all {
    FileUtils.rm "openapi_test.yaml"
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
      OpenAPI::Generator::RoutesProvider::Amber.new,
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
              type: string
          requestBody:
            description: A Hello payload.
            content:
              application/json:
                schema:
                  allOf:
                  - $ref: '#/components/schemas/AmberSpec_Payload'
            required: false
          responses:
            "200":
              description: Hello
              content:
                application/json:
                  schema:
                    allOf:
                    - $ref: '#/components/schemas/AmberSpec_Payload'
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
        options:
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
        head:
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
        "AmberSpec_Payload": {
          "required": [ "hello" ],
          "type": "object",
          "properties": {
            "hello": {
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
end
