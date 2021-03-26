require "../spec_helper"
require "file_utils"

class MockProvider < OpenAPI::Generator::RoutesProvider::Base
  def route_mappings : Array(OpenAPI::Generator::RouteMapping)
    [
      {"get", "/{id}", "Controller::method", ["id"]},
      {"head", "/{id}", "Controller::method", ["id"]},
      {"options", "/{id}", "Controller::method", ["id"]},
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
    base_document = {
      info:       {title: "Test", version: "0.0.1"},
      components: NamedTuple.new,
    }
    OpenAPI::Generator.generate(
      MockProvider.new,
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
      /{id}:
        get:
          tags:
          - tag
          summary: A brief summary of the method.
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          requestBody:
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Model'
              application/x-www-form-urlencoded:
                schema:
                  $ref: '#/components/schemas/Model'
            required: true
          responses:
            "303":
              description: Operation completed successfully, and redirects to /.
            "404":
              description: Not Found.
            "400":
              description: Bad Request.
        options:
          tags:
          - tag
          summary: A brief summary of the method.
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          requestBody:
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Model'
              application/x-www-form-urlencoded:
                schema:
                  $ref: '#/components/schemas/Model'
            required: true
          responses:
            "303":
              description: Operation completed successfully, and redirects to /.
            "404":
              description: Not Found.
            "400":
              description: Bad Request.
        head:
          tags:
          - tag
          summary: A brief summary of the method.
          parameters:
          - name: id
            in: path
            required: true
            schema:
              type: string
            example: id
          requestBody:
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Model'
              application/x-www-form-urlencoded:
                schema:
                  $ref: '#/components/schemas/Model'
            required: true
          responses:
            "303":
              description: Operation completed successfully, and redirects to /.
            "404":
              description: Not Found.
            "400":
              description: Bad Request.
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
