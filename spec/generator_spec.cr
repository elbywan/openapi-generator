require "./spec_helper"
require "file_utils"

class MockProvider < OpenAPI::Generator::RoutesProvider::Base
  def route_mappings : Array(OpenAPI::Generator::RouteMapping)
    [
      {"get", "/{id}", "HelloController::index", ["id"]},
      {"head", "/{id}", "HelloController::index", ["id"]},
      {"options", "/{id}", "HelloController::index", ["id"]},
    ]
  end
end

describe OpenAPI::Generator do
  after_all {
    FileUtils.rm "openapi_test.yaml"
  }

  it "should generate an openapi_test.yaml file" do
    options = {
      output: Path[Dir.current] / "openapi_test.yaml",
    }
    base_doc = {
      info:       {title: "Test", version: "0.0.1"},
      components: NamedTuple.new,
    }
    OpenAPI::Generator.generate(
      MockProvider.new,
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
      /{id}:
        get:
          summary: Says hello
          parameters:
          - name: id
            in: path
            required: true
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
            example: id
          responses:
            "200":
              description: OK
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
            inner_schema:
              all_of:
              - ref: '#/components/schemas/Model::InnerModel'
            cast:
              type: string
        Model::InnerModel:
          required:
          - array_of_int
          type: object
          properties:
            array_of_int:
              type: array
              items:
                type: integer
        Model::ComplexModel:
          required:
          - union_types
          - free_form
          - array_of_hash
          type: object
          properties:
            union_types:
              one_of:
              - type: object
                additional_properties:
                  ref: '#/components/schemas/Model::InnerModel'
              - type: integer
              - type: string
            free_form:
              type: object
              additional_properties: true
            array_of_hash:
              type: array
              items:
                type: object
                additional_properties:
                  one_of:
                  - type: integer
                  - type: string
      responses: {}
      parameters: {}
      examples: {}
      request_bodies: {}
      headers: {}
      security_schemes: {}
      links: {}
      callbacks: {}

    YAML
  end
end
