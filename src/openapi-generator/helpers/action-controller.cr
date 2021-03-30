require "action-controller"
require "json"
require "http"

# Helpers that can be used inside an [ActionController](https://amberframework.org/) Controller to enable inference
# and ensure that the code matches the contract defined in the generated OpenAPI document.
#
# Include this module inside a Controller class to add various macros that you can use to make the generator
# infer some properties of the OpenAPI declaration.
#
# - `body_as` can infer request body types and schemas.
# - `respond_with` can infer responses types and schemas.
# - `query_params` can infer query parameters.
#
# NOTE: Do not forget to call `bootstrap` once before calling `OpenAPI::Generator.generate`.
#
# ```
# require "json"
# require "openapi-generator/helpers/action-controller"
#
# class HelloPayloadController < ActionController::Base
#   include ::OpenAPI::Generator::Controller
#   include ::OpenAPI::Generator::Helpers::ActionController
#
#   @[OpenAPI(
#     <<-YAML
#       summary: Sends a hello payload
#     YAML
#   )]
#   def index
#     # Infers query parameters.
#     query_params "mandatory", description: "A mandatory query parameter"
#     query_params? "optional", description: "An optional query parameter"
#
#     # Infers request body.
#     body_as Payload?, description: "The request payload."
#
#     # Infers responses.
#     respond_with 200, description: "A hello payload." do
#       json Payload.new, type: Payload
#       xml "<hello></hello>", type: String
#     end
#     respond_with 201, description: "A good morning message." do
#       text "Good morning.", type: String
#     end
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
# ActionController::Server.configure do
#   routes :api do
#     route "get", "/hello", HelloPayloadController, :index
#   end
# end
#
# OpenAPI::Generator::Helpers::ActionController.bootstrap
# OpenAPI::Generator.generate(OpenAPI::Generator::RoutesProvider::ActionController.new)
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
#       requestBody:
#         description: The request payload.
#         content:
#           application/json:
#             schema:
#               allOf:
#               - $ref: '#/components/schemas/Payload'
#         required: false
#       responses:
#         "200":
#           description: A hello payload?
#           content:
#             application/json:
#               schema:
#                 allOf:
#                 - $ref: '#/components/schemas/Payload'
#             application/xml:
#               schema:
#                 type: string
#         "201":
#           description: A good morning message.
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
module OpenAPI::Generator::Helpers::ActionController
  # :nodoc:
  alias ControllerResponsesValue = Hash(Int32, {OpenAPI::Response, Hash(String, OpenAPI::Schema)}) | Hash(Int32, {OpenAPI::Response, Nil}) | Hash(Int32, Tuple(OpenAPI::Response, Hash(String, OpenAPI::Schema) | Nil))

  # :nodoc:
  CONTROLLER_RESPONSES = {} of String => ControllerResponsesValue
  # :nodoc:
  HASH_ITEM_REF = [] of {Int32, OpenAPI::Response}
  # :nodoc:
  TYPE_REF = [] of String
  # :nodoc:
  QP_LIST = {} of String => Array(OpenAPI::Parameter)
  # :nodoc:
  BODY_LIST = {} of String => {OpenAPI::RequestBody, Hash(String, OpenAPI::Schema)}

  # Fetch a query parameter and register it in the OpenAPI operation related to the controller method.
  #
  # ```
  # query_params "name", "A user name."
  # ```
  macro query_params(name, description, multiple = false, schema = nil, **args)
    _query_params(
      name: {{name}},
      param: ::OpenAPI::Generator::Helpers::ActionController.init_openapi_parameter(
        name: {{name}},
        "in": "query",
        required: true,
        schema: {% if schema %}{{schema}}{% elsif multiple %}::OpenAPI::Schema.new(
          type: "array",
          items: ::OpenAPI::Schema.new(
            type: "string"
          )
        ){% else %}::OpenAPI::Schema.new(
          type: "string",
        ){% end %},
        description: {{description}},
        {{**args}}
      ),
      required: true,
      multiple: {{multiple}}
    )
  end

  # Fetch an optional query parameter and register it in the OpenAPI operation related to the controller method.
  #
  # ```
  # query_params? "name[]", "One or multiple user names. (optional)", multiple = true
  # ```
  macro query_params?(name, description, multiple = false, schema = nil, **args)
    _query_params(
      name: {{name}},
      param: ::OpenAPI::Generator::Helpers::ActionController.init_openapi_parameter(
        name: {{name}},
        "in": "query",
        required: false,
        schema: {% if schema %}{{schema}}{% elsif multiple %}::OpenAPI::Schema.new(
          type: "array",
          items: ::OpenAPI::Schema.new(
            type: "string"
          )
        ){% else %}::OpenAPI::Schema.new(
          type: "string",
        ){% end %},
        description: {{description}},
        {{**args}}
      ),
      required: false,
      multiple: {{multiple}}
    )
  end

  # :nodoc:
  private macro _query_params(name, param, required = true, multiple = false)
    {% qp_list = ::OpenAPI::Generator::Helpers::ActionController::QP_LIST %}
      {% method_name = "#{@type}::#{@def.name}" %}
      {% unless qp_list.keys.includes? method_name %}
        {% qp_list[method_name] = [] of OpenAPI::Parameter %}
      {% end %}
      {% qp_list[method_name] << param %}
      {% if multiple %}
        %results = params.fetch_all({{name}})
        {% if required %}
          raise NilAssertionError.new if %results.size < 1
        {% end %}
        %results
      {% elsif required %}
        params[{{name}}]
      {% else %}
        params[{{name}}]?
    {% end %}
  end

  # Extracts and serialize the body from the request and registers it in the OpenAPI operation.
  #
  # ```
  # # This will try to case the body as a SomeClass using the SomeClass.new method and assuming that the payload is a json.
  # body_as SomeClass, description: "Some payload.", content_type: "application/json", constructor: new
  # # The content_type, constructor and description can be omitted.
  # body_as SomeClass
  # ```
  macro body_as(type, description = nil, content_type = "application/json", constructor = :from_json)
    {% non_nil_type = type.resolve.union_types.reject { |t| t == Nil }[0] %}
    body_as(
      request_body: ::OpenAPI::Generator::Helpers::ActionController.init_openapi_request_body(
        description: {{description}},
        required: {{!type.resolve.nilable?}}
      ),
      schema: {{non_nil_type}}.to_openapi_schema,
      content_type: {{content_type}}
    )
    %content = request.body.try &.gets_to_end
    if %content
      ::{{non_nil_type}}.{{constructor.id}}(%content)
    end
  end

  # :nodoc:
  private macro body_as(request_body, schema, content_type)
    {% body_list = ::OpenAPI::Generator::Helpers::ActionController::BODY_LIST %}
    {% method_name = "#{@type}::#{@def.name}" %}
    {% unless body_list.keys.includes? method_name %}
      {% body_list[method_name] = {request_body, {} of String => OpenAPI::Schema} %}
    {% end %}
    {% body_list[method_name][1][content_type] = schema %}
  end

  # :nodoc:
  def self.init_openapi_parameter(**args)
    ::OpenAPI::Parameter.new(**args)
  end

  # :nodoc:
  def self.init_openapi_response(description, headers, links, code)
    description = description || HTTP::Status.new(code).description || "#{code}"
    ::OpenAPI::Response.new(
      description: description,
      headers: headers,
      links: links,
      content: nil
    )
  end

  # :nodoc:
  def self.init_openapi_request_body(description, required)
    ::OpenAPI::RequestBody.new(
      description: description,
      required: required,
      content: {} of String => OpenAPI::MediaType
    )
  end

  module ::ActionController::Responders
    {% for method_name, content_type in MIME_TYPES %}
      macro {{method_name.id}}(body, type = nil, schema = nil, &block : IO -> Nil)
        {{method_name}}(
          schema: \{% if schema %}\{{schema}}\{%elsif type%}\{{type}}.to_openapi_schema\{% else %}::OpenAPI::Schema.new\{%end%},
          content_type: {{content_type}}
        )
        {{method_name}}(obj: \{{body}}\{% if type %}.as(\{{type}})\{% end %})
      end

      macro {{method_name.id}}(schema, content_type)
        \{% hash_ref = ::OpenAPI::Generator::Helpers::ActionController::HASH_ITEM_REF[0] %}
        \{% code = hash_ref[0] %}
        \{% response = hash_ref[1] %}
        \{% type_name = ::OpenAPI::Generator::Helpers::ActionController::TYPE_REF[0] %}
        \{% controller_responses = ::OpenAPI::Generator::Helpers::ActionController::CONTROLLER_RESPONSES %}
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

  # Same as the [ActionController method](https://docs.amberframework.org/action-controller/guides/controllers/respond-with) with automatic response inference.
  macro respond_with(code = 200, description = nil, headers = nil, links = nil, &)
    respond_with(code: {{code}}, response: ::OpenAPI::Generator::Helpers::ActionController.init_openapi_response(
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
    respond_with(status: {{ code }}) do
      {{ yield }}
    end
  end

  # Same as the [ActionController method](https://docs.amberframework.org/action-controller/guides/controllers/respond-with) but without specifying any content and with automatic response inference.
  macro respond_without_body(code = 200, description = nil, headers = nil, links = nil)
    respond_without_body(code: {{code}}, response: ::OpenAPI::Generator::Helpers::ActionController.init_openapi_response(
      description: {{description}},
      code: {{code}},
      headers: {{headers}},
      links: {{links}}
    ))
  end

  # :nodoc:
  macro respond_without_body(code, response)
    {% type_name = @type.stringify %}
    {% controller_responses = ::OpenAPI::Generator::Helpers::ActionController::CONTROLLER_RESPONSES %}
    {% method_name = type_name + "::#{@def.name}" %}
    {% unless controller_responses[method_name] %}
      {% controller_responses[method_name] = {} of Int32 => Hash(String, {OpenAPI::Response, Hash(String, OpenAPI::Schema)}) %}
    {% end %}
    {% unless controller_responses[method_name][code] %}
      {% controller_responses[method_name][code] = {response, nil} %}
    {% end %}
    response.status_code = {{code}}
    response.close
  end

  # Run this method exactly once before generating the schema to register all the inferred properties.
  def self.bootstrap
    ::ActionController::Server.new(3000, "127.0.0.1")
    ::OpenAPI::Generator::Helpers::ActionController::QP_LIST.each { |method, params|
      openapi_op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[method]?
      next unless openapi_op
      unless openapi_op["parameters"]?
        openapi_op.as_h[YAML::Any.new "parameters"] = YAML::Any.new([] of YAML::Any)
      end
      params.each { |param|
        openapi_op["parameters"].as_a << YAML.parse(param.to_yaml)
      }
    }

    ::OpenAPI::Generator::Helpers::ActionController::CONTROLLER_RESPONSES.each { |method, responses|
      op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[method]?
      next unless op
      responses.each { |(code, values)|
        response, schemas = values
        schemas.try &.each { |content_type, schema|
          unless response.content
            response.content = {} of String => OpenAPI::MediaType
          end
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

    ::OpenAPI::Generator::Helpers::ActionController::BODY_LIST.each { |method, value|
      op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[method]?
      next unless op
      request_body, schemas = value
      schemas.each { |content_type, schema|
        request_body.content.try(&.[content_type] = ::OpenAPI::MediaType.new(schema: schema))
      }
      unless op["requestBody"]?
        op.as_h[YAML::Any.new "requestBody"] = YAML.parse(request_body.to_yaml)
      end
    }
  end
end
