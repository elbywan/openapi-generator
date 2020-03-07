# Including this module will register all the methods having
# an OpenAPI annotation and match them later on with routes.
module OpenAPI::Generator::Controller
  extend self
  CONTROLLER_OPS = {} of String => String

  # This annotation is used to associate the OpenAPI documentation with controllers methods.
  annotation OpenAPI
  end

  # When included
  macro included
    {% verbatim do %}

    macro method_added(method)
      # If the method is annotated register it by adding a stringified form to the global ops constant.
      {% open_api_annotation = method.annotation(OpenAPI) %}
      {% if open_api_annotation %}
        {% for yaml_op in open_api_annotation.args %}
          {% CONTROLLER_OPS["#{@type}:#{method.name}"] = yaml_op %}
        {% end %}
      {% end %}
    end
    {% end %}
  end

  # Openapi shortcuts
  private module Schema
    extend self

    def object(schema, *, content_type = "application/json")
      <<-YAML
      #{content_type}: {
      schema: {
          $ref: '#/components/schemas/#{schema.name}'
        }
      }
      YAML
    end

    def array(schema, *, content_type = "application/json")
      <<-YAML
      #{content_type}: {
        schema: {
            type: array,
            items: {
              $ref: '#/components/schemas/#{schema.name}'
            }
        }
      }
      YAML
    end

    def array_of_strings(*, content_type = "application/json")
      <<-YAML
      #{content_type}: {
        schema: {
            type: array,
            items: {
              type: string
            }
        }
      }
      YAML
    end

    def error(code, message = nil)
      <<-YAML
      #{code}: {
      description: #{message || HTTP::Status.new(code).description}.
      }
      YAML
    end

    def qp(name, description)
      <<-YAML
      - {
        in: query,
        name: "#{name}",
        description: "#{description}",
        required: false
      }
      YAML
    end

    def qp_offset
      <<-YAML
      #{Schema.qp "offset", "The number of items to skip before starting to collect the result set."}
      YAML
    end

    def qp_limit
      <<-YAML
      #{Schema.qp "limit", "The maximum number of items to return. Defaults to 100."}
      YAML
    end

    def header(name, description, type = "string")
      <<-YAML
      #{name}: {
        schema: {
          type: #{type}
        },
        description: #{description}
      }
      YAML
    end

    def header_param(name, description)
      <<-YAML
      - {
        in: header,
        name: #{name},
        description: #{description}
      }
      YAML
    end
  end
end
