require "log"
require "./providers/base"

# An OpenAPI yaml specifications file generator.
#
# ### Complete example
#
# ```
# require "openapi-generator"
#
# # The following example is using [Amber](https://amberframework.org/)
# # but this library is compatible with any web framework.
#
# require "amber"
# require "openapi-generator/providers/amber"
#
# # Optional: auto-serialize classes into openapi schema.
# # A typed Model class can be used as the source of truth.
# class Coordinates
#   extend OpenAPI::Generator::Serializable
#
#   def initialize(@lat, @long); end
#
#   property lat : Int32
#   property long : Int32
# end
#
# # Annotate the methods that will appear in the openapi file.
# class Controller < Amber::Controller::Base
#   include OpenAPI::Generator::Controller
#
#   @[OpenAPI(<<-YAML
#     tags:
#     - tag
#     summary: A brief summary of the method.
#     requestBody:
#       required: true
#       content:
#         #{Schema.ref Coordinates}
#     required: true
#     responses:
#       200:
#         description: OK
#       #{Schema.error 404}
#   YAML
#   )]
#   def method
#     # Some code…
#   end
# end
#
# # Add the routes.
# Amber::Server.configure do
#   routes :api do
#     post "/method/:id", Controller, :method
#   end
# end
#
# # Generate the openapi file.
#
# OpenAPI::Generator.generate(
#   provider: OpenAPI::Generator::RoutesProvider::Amber.new
# )
# ```
#
# Will produce an `./openapi.yaml` file with the following contents:
#
# ```yaml
# ---
# openapi: 3.0.1
# info:
#   title: Server
#   version: "1"
# paths:
#   /method/{id}:
#     post:
#       tags:
#       - tag
#       summary: A brief summary of the method.
#       parameters:
#       - name: id
#         in: path
#         required: true
#         schema:
#           type: string
#         example: id
#       requestBody:
#         content:
#           application/json:
#             schema:
#               $ref: '#/components/schemas/Coordinates'
#         required: true
#       responses:
#         "200":
#           description: OK
#         "404":
#           description: Not Found.
#     options:
#       tags:
#       - tag
#       summary: A brief summary of the method.
#       parameters:
#       - name: id
#         in: path
#         required: true
#         schema:
#           type: string
#         example: id
#       requestBody:
#         content:
#           application/json:
#             schema:
#               $ref: '#/components/schemas/Coordinates'
#         required: true
#       responses:
#         "200":
#           description: OK
#         "404":
#           description: Not Found.
# components:
#   schemas:
#     Coordinates:
#       required:
#       - lat
#       - long
#       type: object
#       properties:
#         lat:
#           type: integer
#         long:
#           type: integer
#   responses: {}
#   parameters: {}
#   examples: {}
#   requestBodies: {}
#   headers: {}
#   securitySchemes: {}
#   links: {}
#   callbacks: {}
# ```
#
# ### Usage
#
#
module OpenAPI::Generator
  extend self

  Log = ::Log.for(self)

  # A RouteMapping type is a tuple with the following shape: `{method, full_path, key, path_params}`
  # - method: The HTTP Verb of the route. (ex: `"get"`)
  # - full_path: The full path representation of the route with path parameters between curly braces. (ex: `"/name/{id}"`)
  # - key: The fully qualified name of the method mapped to the route. (ex: `"Controller::show"`)
  # - path_params: A list of path parameter names. (ex: `["id", "name"]`)
  alias RouteMapping = Tuple(String, String, String, Array(String))

  DEFAULT_OPTIONS = {
    output: Path[Dir.current] / "openapi.yaml",
  }

  # Generate an OpenAPI yaml file.
  #
  # An `OpenAPI::Generator::RoutesProvider::Base` implementation must be provided.
  #
  # Currently, only the [Amber](https://amberframework.org/) and [Lucky](https://luckyframework.org) providers are included out of the box
  # but writing a custom provider should be easy.
  #
  # ### Example
  #
  # ```
  # class MockProvider < OpenAPI::Generator::RoutesProvider::Base
  #   def route_mappings : Array(OpenAPI::Generator::RouteMapping)
  #     [
  #       {"get", "/{id}", "HelloController::index", ["id"]},
  #       {"head", "/{id}", "HelloController::index", ["id"]},
  #       {"options", "/{id}", "HelloController::index", ["id"]},
  #     ]
  #   end
  # end
  #
  # options = {
  #   output: Path[Dir.current] / "public" / "openapi.yaml",
  # }
  # base_document = {
  #   info: {
  #     title:   "Test",
  #     version: "0.0.1",
  #   },
  #   components: NamedTuple.new,
  # }
  # OpenAPI::Generator.generate(
  #   MockProvider.new,
  #   options: options,
  #   base_document: base_document
  # )
  # ```
  def generate(
    provider : OpenAPI::Generator::RoutesProvider::Base,
    *,
    options = NamedTuple.new,
    base_document = {
      info: {
        title:   "Server",
        version: "1",
      },
    }
  )
    routes = provider.route_mappings
    path_items = {} of String => OpenAPI::PathItem
    options = DEFAULT_OPTIONS.merge(options)

    # Sort the routes by path.
    routes = routes.sort do |a, b|
      a[1] <=> b[1]
    end

    # For each route quadruplet…
    routes.each do |route|
      method, full_path, key, path_params = route

      # Get the matching registered controller operation (in YAML format).
      if yaml_op = Controller::CONTROLLER_OPS[key]?
        begin
          yaml_op_any = yaml_op
          path_items[full_path] ||= OpenAPI::PathItem.new

          op = OpenAPI::Operation.from_json yaml_op_any.to_json
          if path_params.size > 0
            op.parameters ||= [] of (OpenAPI::Parameter | OpenAPI::Reference)
          end
          path_params.each { |param|
            op.parameters.not_nil!.unshift OpenAPI::Parameter.new(
              in: "path",
              name: param,
              required: true,
              example: param,
              schema: OpenAPI::Schema.new(type: "string")
            )
          }

          {% begin %}
          {% methods = %w(get put post delete options head patch trace) %}

          case method
          {% for method in methods %}
          when "{{method.id}}"
            path_items[full_path].{{method.id}} = op
          {% end %}
          else
            raise "Unsupported method: #{method}."
          end

          {% end %}
        rescue err
          Log.error { "Error while generating bindings for path [#{full_path}].\n\n#{err}\n\n#{yaml_op}" }
        end
      else
        # Warn if there is not openapi documentation for a route.
        Log.warn { "#{full_path} (#{method.upcase}) : Route is undocumented." }
      end
    end

    base_document = base_document.merge({
      openapi:    "3.0.1",
      info:       base_document["info"],
      paths:      path_items,
      components: (base_document["components"]? || NamedTuple.new).merge({
        # Generate schemas.
        schemas: Serializable.schemas,
      }),
    })

    doc = OpenAPI.build do |api|
      api.document **base_document
    end
    File.write options["output"].to_s, doc.to_yaml
  end
end
