require "json"
require "file_utils"
require "http"
require "lucky"
require "../spec_helper"
require "../../src/openapi-generator/helpers/lucky"

class Payload
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@hello : String = "world")
  end
end

class Hello::Index < Lucky::Action
  include OpenAPI::Generator::Helpers::Lucky

  default_format :text

  param mandatory : String, description: "A mandatory query parameter"
  param optional : String?, description: "An optional query parameter"

  open_api <<-YAML
    summary: Sends a hello payload
    responses:
      200:
        description: Overriden
  YAML

  post "/hello" do
    body_as Payload?, description: "A Hello payload."

    json Payload.new, type: Payload, description: "Hello"
    xml "<hello></hello>", description: "Hello"
    plain_text "Good morning.", status: 201, description: "Not Overriden"
    plain_text "Ouch.", status: 400
  end
end

require "../../src/openapi-generator/providers/lucky.cr"

OpenAPI::Generator::Helpers::Lucky.bootstrap

describe OpenAPI::Generator::Helpers::Lucky do
  after_all {
    FileUtils.rm "openapi_test.yaml"
  }

  it "should infer the status codes and contents of the response body" do
    options = {
      output: Path[Dir.current] / "openapi_test.yaml",
    }
    base_doc = {
      info:       {title: "Test", version: "0.0.1"},
      components: NamedTuple.new,
    }
    OpenAPI::Generator.generate(
      OpenAPI::Generator::RoutesProvider::Lucky.new,
      options: options,
      base_doc: base_doc
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
                text/xml:
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
              $ref: '#/components/schemas/Model%3A%3AInnerModel'
            cast:
              type: string
              example: "1"
        Model::InnerModel:
          required:
          - array_of_int
          type: object
          properties:
            array_of_int:
              type: array
              items:
                type: integer
              writeOnly: true
        Model::ComplexModel:
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
                  $ref: '#/components/schemas/Model%3A%3AInnerModel'
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
          - hello
          type: object
          properties:
            hello:
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
end
