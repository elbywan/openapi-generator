require "amber"
require "http"

# Helpers that can be used to infer some properties of the OpenAPI operation.
#
# ```
# require "json"
# require "openapi-generator/helpers/amber"
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
#     query_params "mandatory", description: "A mandatory query parameter"
#     query_params? "optional", description: "An optional query parameter"
#
#     respond_with 200, description: "Overriden" do
#       json Payload.new, type: Payload
#       xml "<hello></hello>", type: String
#     end
#
#     respond_with 201, description: "Not Overriden" do
#       text "Good morning.", type: String
#     end
#
#     respond_with 400 do
#       text "Ouch.", type: String
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
#       parameters:
#       - name: mandatory
#         in: query
#         description: A mandatory query parameter
#         required: true
#         schema:
#           type: string
#       - name: optional
#         in: query
#         description: An optional query parameter
#         required: false
#         schema:
#           type: string
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
  QP_LIST = {} of String => Array({String, String, Bool})

  # Fetch a query parameter and register it in the OpenAPI operation related to the controller method.
  #
  # ```
  # query_params "name", "A user name."
  # ```
  macro query_params(name, description = nil)
    {% qp_list = ::OpenAPI::Generator::Helpers::Amber::QP_LIST %}
    {% method_name = "#{@type}::#{@def.name}" %}
    {% unless qp_list.keys.includes? method_name %}
      {% qp_list[method_name] = [] of ({String, String, Bool}) %}
    {% end %}
    {% qp_list[method_name] << {name, description || "", true} %}
    params[{{name}}]
  end

  # Fetch an optional query parameter and register it in the OpenAPI operation related to the controller method.
  #
  # ```
  # query_params? "name[]", "One or multiple user names. (optional)", multiple = true
  # ```
  macro query_params?(name, description = nil, *, multiple = false)
    {% qp_list = ::OpenAPI::Generator::Helpers::Amber::QP_LIST %}
    {% method_name = "#{@type}::#{@def.name}" %}
    {% unless qp_list.keys.includes? method_name %}
      {% qp_list[method_name] = [] of ({String, String, Bool}) %}
    {% end %}
    {% qp_list[method_name] << {name, description || "", false} %}
    {% if multiple %}
      params.fetch_all({{name}})
    {% else %}
      params[{{name}}]?
    {% end %}
  end

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
      macro {{method_name}}(body, type = nil, schema = nil)
        Content.{{method_name}}(
          schema: \{% if schema %}\{{schema}}\{%elsif type%}\{{type}}.to_openapi_schema\{% else %}::OpenAPI::Schema.new\{%end%},
          content_type: {{content_type}}
        )
        {{method_name}}(value: \{{body}}\{% if type %}.as(\{{type}})\{% end %}{% if method_name == "json" %}.to_json{% else %}.to_s{% end %})
      end

      macro {{method_name}}(schema, content_type)
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

  # Run this method exactly once before generating the schema to register all the inferred properties.
  def self.bootstrap
    ::OpenAPI::Generator::Helpers::Amber::QP_LIST.each { |method, params|
      openapi_op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[method]?
      next unless openapi_op
      unless openapi_op["parameters"]?
        openapi_op.as_h[YAML::Any.new "parameters"] = YAML::Any.new([] of YAML::Any)
      end
      params.each { |param|
        description : String? = param[1].empty? ? nil : param[1]
        query_parameter = YAML.parse({
          "name" => param[0],
          "in" => "query",
          "description" => description,
          "required" => param[2],
          "schema" => {
            "type" => "string"
          }
        }.to_yaml)
        openapi_op["parameters"].as_a << query_parameter
      }
    }

    OpenAPI::Generator::Controller::CONTROLLER_OPS.each { |(method, op)|
      matching_responses = CONTROLLER_RESPONSES.find { |(key, _)|
        key == method
      }
      next unless matching_responses
      matching_responses[1].each { |(code, values)|
        response, schemas = values
        schemas.each { |content_type, schema|
          response.content.try(&.[content_type] = ::OpenAPI::MediaType.new(schema: schema))
        }
        unless op["responses"]?
          op.as_h[YAML::Any.new "responses"] = YAML::Any.new(Hash(YAML::Any, YAML::Any).new)
        end
        original_yaml_response = op["responses"].as_h.find { |(key, value)|
          key.raw.to_s == code.to_s
        }
        if !original_yaml_response
          op["responses"].as_h[YAML::Any.new code.to_s] = YAML.parse response.to_yaml
        else
          unless original_yaml_response[1]["description"]?
            original_yaml_response[1].as_h[YAML::Any.new "description"] = YAML::Any.new ""
          end
          original_response = ::OpenAPI::Response.from_json(original_yaml_response[1].to_json)
          op["responses"].as_h[YAML::Any.new code.to_s] = YAML.parse(::OpenAPI::Response.new(
            description: response.description || original_response.description,
            headers: original_response.headers || response.headers,
            links: original_response.links || response.links,
            content: original_response.content || response.content
          ).to_yaml)
        end
      }
    }
  end
end
