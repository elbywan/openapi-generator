# This module, when included, will register every instance methods annotated with the `OpenAPI` annotation.
#
# ### Example
#
# ```
# class Controller
#   include OpenAPI::Generator::Controller
#
#   @[OpenAPI(<<-YAML
#     tags:
#     - tag
#     summary: A brief summary of the method.
#     requestBody:
#       content:
#         #{Schema.ref SerializableClass}
#         application/x-www-form-urlencoded:
#           schema:
#             $ref: '#/components/schemas/SerializableClass'
#       required: true
#     responses:
#       "303":
#         description: Operation completed successfully, and redirects to /.
#       "404":
#         description: Data not found.
#       #{Schema.error 400}
#   YAML
#   )]
#   def method; end
# end
# ```
#
# ### Usage
#
# Including this module will register and mark every instance method annotated with a valid `@[OpenAPI]` annotation during the compilation phase.
# These methods will then be taken into account when calling the `Generator` as long as the method can be mapped to a route.
#
# The `Schema` module contains various helpers to generate YAML parts.
module OpenAPI::Generator::Controller
  CONTROLLER_OPS = {} of String => String

  # This annotation is used to register a controller method as an OpenAPI [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#operationObject).
  #
  # The argument must be a valid YAML representation of an OpenAPI operation object.
  #
  # ```
  # @[OpenAPI(<<-YAML
  #   tags:
  #   - tag
  #   summary: A brief summary of the method.
  #   responses:
  #     200:
  #       description: Ok.
  # YAML
  # )]
  # def method
  # end
  # ```
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
          {% CONTROLLER_OPS["#{@type}::#{method.name}"] = yaml_op %}
        {% end %}
      {% end %}
    end
    {% end %}
  end

  # This module contains various OpenAPI yaml syntax shortcuts.
  module Schema
    extend self

    # Generates a schema reference as a [media type object](https://swagger.io/docs/specification/media-types/).
    #
    # Useful when dealing with objects including the `Serializable` module.
    #
    # ```
    # Schema.ref SerializableClass, content_type: "application/x-www-form-urlencoded"
    #
    # # Produces:
    #
    # <<-YAML
    # application/x-www-form-urlencoded:
    #   schema:
    #     $ref: '#/components/schemas/SerializableClass'
    # YAML
    # ```
    def ref(schema, *, content_type = "application/json")
      <<-YAML
      #{content_type}: {
      schema: {
          $ref: '#/components/schemas/#{schema.name}'
        }
      }
      YAML
    end

    # Generates an array of schema references as a [media type object](https://swagger.io/docs/specification/media-types/).
    #
    # Useful when dealing with objects including the `Serializable` module.
    #
    # ```
    # Schema.ref_array SerializableClass, content_type: "application/x-www-form-urlencoded"
    #
    # # Produces:
    #
    # <<-YAML
    # application/x-www-form-urlencoded:
    #   schema:
    #     type: array,
    #     items:
    #       $ref: '#/components/schemas/SerializableClass'
    # YAML
    # ```
    def ref_array(schema, *, content_type = "application/json")
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

    # Generates an array of string as a [media type object](https://swagger.io/docs/specification/media-types/).
    #
    # ```
    # Schema.string_array content_type: "application/x-www-form-urlencoded"
    #
    # # Produces:
    #
    # <<-YAML
    # application/x-www-form-urlencoded:
    #   schema:
    #     type: array,
    #     items:
    #       type: string
    # YAML
    # ```
    def string_array(*, content_type = "application/json")
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

    # Generate an error response as a [response object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#responses-object-example).
    #
    # ```
    # # message is optional and defaults to a [standard error description](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml) based on the code.
    # Schema.error 400, message: "Bad Request"
    #
    # # Produces:
    #
    # <<-YAML
    # 400:
    #   description: Bad Request
    # YAML
    # ```
    def error(code, message = nil)
      <<-YAML
      #{code}: {
      description: #{message || HTTP::Status.new(code).description}.
      }
      YAML
    end

    # Generate a query parameter as a [parameter object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#parameterObject).
    #
    # ```
    # Schema.qp "id", "Filter by id", required: true, type: "integer"
    #
    # # Produces:
    #
    # <<-YAML
    # - in: query
    #   name: id
    #   description: Filter by id
    #   required: true
    #   schema:
    #     type: integer
    # YAML
    # ```
    def qp(name, description, *, required = false, type = "string")
      <<-YAML
      - {
        in: query,
        name: "#{name}",
        description: "#{description}",
        required: #{required},
        schema: {
          type: #{type}
        }
      }
      YAML
    end

    # Generate a header [parameter object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#parameterObject).
    #
    # ```
    # Schema.header_param "X-Header", "A custom header", required: true
    #
    # # Produces
    #
    # <<-YAML
    # - in: header
    #   name: "X-Header"
    #   description: A custom header
    #   required: true
    # YAML
    # ```
    def header_param(name, description, *, required = false)
      <<-YAML
      - {
        in: header,
        name: #{name},
        description: #{description},
        required: #{required}
      }
      YAML
    end

    # Generate a [header object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#header-object).
    #
    # ```
    # Schema.header "X-Header", "A custom header", type: "string"
    #
    # # Produces:
    #
    # <<-YAML
    # "X-Header":
    #   schema:
    #     type: string
    #   description: A custom header
    # YAML
    # ```
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
  end
end
