require "action-controller/server"
require "action-controller"
require "./base"

# Provides the list of declared routes.
class OpenAPI::Generator::RoutesProvider::ActionController < OpenAPI::Generator::RoutesProvider::Base
  # Return a list of routes mapped with the action classes.

  def route_mappings : Array(RouteMapping)
    # A RouteMapping type is a tuple with the following shape: `{method, full_path, key, path_params}`
    # - method: The HTTP Verb of the route. (ex: `"get"`)
    # - full_path: The full path representation of the route with path parameters between curly braces. (ex: `"/name/{id}"`)
    # - key: The fully qualified name of the method mapped to the route. (ex: `"Controller::show"`)
    # - path_params: A list of path parameter names. (ex: `["id", "name"]`)
    # alias RouteMapping = Tuple(String, String, String, Array(String))
    routes = [] of RouteMapping

    # route typing : {String, Symbol, Symbol, String} (Controller, method, verb, uri)
    ::ActionController::Server.routes.each do |route|
      route_controller, route_method, method, path = route
      key = "#{route_controller}::#{route_method}"
      path_params = [] of String

      full_path = path.chomp('/').split('/').join('/') do |i|
        if i.starts_with?(':')
          i = i.lstrip(':')
          path_params << i
          "{#{i}}"
        else
          i
        end
      end

      routes << {method.to_s, full_path, key, path_params}
    end

    routes
  end
end
