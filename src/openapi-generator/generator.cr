require "./providers/base"

module OpenAPI::Generator
  extend self

  alias RouteMapping = Tuple(String, String, String, Array(String))

  DEFAULT_OPTIONS = {
    output: Path[Dir.current] / "openapi.yaml",
  }

  # Generate the OpenAPI yaml file.
  # ameba:disable Metrics/CyclomaticComplexity
  def generate(
    provider : OpenAPI::Generator::RoutesProvider::Base,
    *,
    options = NamedTuple.new,
    base_doc = {
      info: {
        title:   "Server",
        version: "1",
      },
      components: NamedTuple.new,
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
          yaml_op_any = YAML.parse(yaml_op)
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
              example: param
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
          Amber.logger.error "Error while generating bindings for path [#{full_path}].\n\n#{err}\n\n#{yaml_op}", "OpenAPI Generation"
        end
      else
        # Warn if there is not openapi documentation for a route.
        Amber.logger.warn "#{full_path} (#{method.upcase}) : Route is undocumented.", "OpenAPI Generation"
      end
    end

    base_doc = base_doc.merge({
      openapi:    "3.0.1",
      info:       base_doc["info"],
      paths:      path_items,
      components: base_doc["components"].merge({
        # Generate schemas.
        schemas: Serializable.schemas,
      }),
    })

    doc = OpenAPI.build do |api|
      api.document **base_doc
    end
    File.write options["output"].to_s, doc.to_yaml
  end
end
