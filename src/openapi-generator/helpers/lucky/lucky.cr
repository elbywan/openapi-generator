require "lucky"
require "open_api"
require "./*"

module OpenAPI::Generator::Helpers::Lucky
  macro included
    include ::OpenAPI::Generator::Controller
    open_api
  end

  # Run this method exactly once before generating the schema to register all the inferred properties.
  def self.bootstrap
    # ameba:disable Lint/LiteralInCondition
    if false
      # Dummy!
      # The compiler must access the call to expand the inference macros.
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      request = HTTP::Request.new(method: "get", resource: "/")
      context = HTTP::Server::Context.new(request: request, response: response)
      ::Lucky::RouteHandler.new.call(context)
    end

    ::OpenAPI::Generator::Helpers::Lucky::QP_LIST.each { |key, params|
      openapi_op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[key]?
      next unless openapi_op
      unless openapi_op["parameters"]?
        openapi_op.as_h[YAML::Any.new "parameters"] = YAML::Any.new([] of YAML::Any)
      end
      params.each { |param|
        openapi_op["parameters"].as_a << YAML.parse(param.to_yaml)
      }
    }

    ::OpenAPI::Generator::Helpers::Lucky::CONTROLLER_RESPONSES.each { |key, responses|
      op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[key]?
      next unless op
      responses.each { |(code, values)|
        response, schemas = values
        schemas.try &.each { |content_type, schema|
          unless response.content
            response.content = {} of String => ::OpenAPI::MediaType
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

    ::OpenAPI::Generator::Helpers::Lucky::BODY_LIST.each { |key, value|
      op = ::OpenAPI::Generator::Controller::CONTROLLER_OPS[key]?
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
