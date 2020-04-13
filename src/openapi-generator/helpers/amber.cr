require "amber"
require "http"

# Helpers that can be used to infer some properties of the OpenAPI operation.
#
# ```
# require "json"
# require "openapi_generator/helpers/amber"
#
# class HelloPayloadController < Amber::Controller::Base
#   include ::OpenAPI::Generator::Controller
#   include ::OpenAPI::Generator::Helpers::Amber
#
#   @[OpenAPI(
#     <<-YAML
#       summary: Sends a hello payload
#       responses:
#         200:
#           description: Hello
#     YAML
#   )]
#   def index
#     respond_with 200, description: "Overriden" do
#       json Payload.new
#       xml "<hello></hello>"
#     end
#     respond_with 201, description: "Not Overriden" do
#       text "Good morning."
#     end
#     respond_with 400 do
#       text "Ouch."
#     end
#   end
# end
#
# class Payload
#   include JSON::Serializable
#   extend OpenAPI::Generator::Serializable
#
#   def initialize(@hello : String = "world")
#   end
# end
#
# Amber::Server.configure do
#   routes :api do
#     route "get", "/hello", HelloPayloadController, :index
#   end
# end
#
# OpenAPI::Generator::Helpers::Amber.bootstrap
# OpenAPI::Generator.generate(OpenAPI::Generator::RoutesProvider::Amber.new)
# ```
#
# Will produce:
#
# ```yaml
# ---
# openapi: 3.0.1
# info:
#   title: Test
#   version: 0.0.1
# paths:
#   /hello:
#     get:
#       summary: Sends a hello payload
#       responses:
#         "200":
#           description: Hello
#           content:
#             application/json:
#               schema:
#                 allOf:
#                 - $ref: '#/components/schemas/Payload'
#             application/xml:
#               schema:
#                 type: string
#         "201":
#           description: Not Overriden
#           content:
#             text/plain:
#               schema:
#                 type: string
#         "400":
#           description: Bad Request
#           content:
#             text/plain:
#               schema:
#                 type: string
# components:
#   schemas:
#     Payload:
#       required:
#       - hello
#       type: object
#       properties:
#         hello:
#           type: string
#   responses: {}
#   parameters: {}
#   examples: {}
#   requestBodies: {}
#   headers: {}
#   securitySchemes: {}
#   links: {}
#   callbacks: {}
# ```
module OpenAPI::Generator::Helpers::Amber
  # :nodoc:
  CONTROLLER_RESPONSES = {} of String => Hash(Int32, {OpenAPI::Response, Hash(String, OpenAPI::Schema)})
  # :nodoc:
  HASH_ITEM_REF = [] of {Int32, OpenAPI::Response}
  # :nodoc:
  TYPE_REF = [] of String

  # :nodoc:
  def self.init_openapi_response(description, headers, links, code)
    description = description || HTTP::Status.new(code).description || "#{code}"
    ::OpenAPI::Response.new(
      description: description,
      headers: headers,
      links: links,
      content: {} of String => OpenAPI::MediaType
    )
  end

  class ::Amber::Controller::Helpers::Responders::Content
    {% for method_name, content_type in TYPE %}
      macro {{method_name}}(body, schema = nil)
        Content.{{method_name}}(
          schema: \{% if schema %}\{{schema}}\{%else%}\{{body}}.class.to_openapi_schema\{%end%},
          content_type: {{content_type}},
          _ignore: 0
        )
        {{method_name}}(value: \{{body}}{% if method_name == "json" %}.to_json{% else %}.to_s{% end %})
      end

      macro {{method_name}}(schema, content_type, _ignore)
        \{% hash_ref = ::OpenAPI::Generator::Helpers::Amber::HASH_ITEM_REF[0] %}
        \{% code = hash_ref[0] %}
        \{% response = hash_ref[1] %}
        \{% type_name = ::OpenAPI::Generator::Helpers::Amber::TYPE_REF[0] %}
        \{% controller_responses = ::OpenAPI::Generator::Helpers::Amber::CONTROLLER_RESPONSES %}
        \{% method_name = type_name + "::#{@def.name}" %}
        \{% unless controller_responses[method_name] %}
          \{% controller_responses[method_name] = {} of Int32 => Hash(String, {OpenAPI::Response, Hash(String, OpenAPI::Schema)}) %}
        \{% end %}
        \{% unless controller_responses[method_name][code] %}
          \{% controller_responses[method_name][code] = {response, {} of String => OpenAPI::Schema} %}
        \{% end %}
        \{% controller_responses[method_name][code][1][content_type] = schema %}
      end
    {% end %}
  end

  # Same as the [Amber method](https://docs.amberframework.org/amber/guides/controllers/respond-with) with automatic response inference.
  macro respond_with(code = 200, description = nil, headers = nil, links = nil, &)
    respond_with(code: {{code}}, response: ::OpenAPI::Generator::Helpers::Amber.init_openapi_response(
      description: {{description}},
      code: {{code}},
      headers: {{headers}},
      links: {{links}}
    )) do
      {{ yield }}
    end
  end

  # :nodoc:
  macro respond_with(code, response, &)
    {% HASH_ITEM_REF.clear %}
    {% TYPE_REF.clear %}
    {% HASH_ITEM_REF << {code, response} %}
    {% TYPE_REF << @type.stringify %}
    self.respond_with {{ code }} do
      {{ yield }}
    end
  end

  # Run this method exactly once before generating the schema to register all the infered properties.
  def self.bootstrap
    OpenAPI::Generator::Controller::CONTROLLER_OPS.each { |(method, op)|
      # puts method
      matching_responses = CONTROLLER_RESPONSES.find { |(key, _)|
        key == method
      }
      next unless matching_responses
      matching_responses[1].each { |(code, values)|
        response, schemas = values
        schemas.each { |content_type, schema|
          response.content.try(&.[content_type] = ::OpenAPI::MediaType.new(schema: schema))
        }
        original_yaml_response = op["responses"].as_h.find { |(key, value)|
          key.raw.to_s == code.to_s
        }
        if !original_yaml_response
          op["responses"].as_h[YAML::Any.new code.to_s] = YAML.parse response.to_yaml
        else
          original_response = ::OpenAPI::Response.from_json(original_yaml_response[1].to_json)
          op["responses"].as_h[YAML::Any.new code.to_s] = YAML.parse(::OpenAPI::Response.new(
            description: original_response.description || response.description,
            headers: original_response.headers || response.headers,
            links: original_response.links || response.links,
            content: original_response.content || response.content
          ).to_yaml)
        end
      }
    }
  end
end
