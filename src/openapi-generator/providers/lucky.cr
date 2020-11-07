require "lucky"
require "./base"

# Provides the list of declared routes.
class OpenAPI::Generator::RoutesProvider::Lucky < OpenAPI::Generator::RoutesProvider::Base
  # Return a list of routes mapped with the action classes.
  def route_mappings : Array(RouteMapping)
    routes = [] of RouteMapping
    ::Lucky::Router.routes.map do |route|
      paths, path_params = route.path
        # Split on /
        .split("/")
        # Reformat positional parameters from ":xxx" or "?:xxx" to "{xxx}"
        .reduce({[] of String, [] of String}) { |acc, segment|
          path_array, params = acc
          if segment.starts_with?(':') || segment.starts_with?('?')
            param = segment.gsub(/^[?:]+/, "")
            path_array << "{#{param}}"
            params << param
            acc
          else
            path_array << segment
            acc
          end
        }
      routes << {route.method.to_s, paths.join("/"), route.action.to_s, path_params}
    end
    routes
  end
end
