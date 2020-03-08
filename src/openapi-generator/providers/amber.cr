require "amber"
require "./base"

module Amber::Router
  class RouteSet(T)
    # Used to programmatically retrieve the list of all routes registered.
    def each_route(cb)
      @segments.each do |segment|
        if segment.is_a? TerminalSegment
          cb.call(segment.full_path, segment.route)
        elsif segment.route_set && !(segment.is_a? GlobSegment)
          segment.route_set.each_route(cb)
        end
      end
    end
  end
end

# Provides the list of routes declared in an Amber Framework instance.
class OpenAPI::Generator::RoutesProvider::Amber < OpenAPI::Generator::RoutesProvider::Base
  # Initialize the provider with a list of allowed HTTP verbs and path prefixes to filter the routes.
  def initialize(@included_methods : Array(String)? = nil, @included_paths : Array(String)? = nil)
  end

  # Return a list of routes mapped with the controllers and methods.
  def route_mappings : Array(RouteMapping)
    routes = [] of RouteMapping
    ::Amber::Server.router.routes.each_route ->(full_path : String, route : ::Amber::Route) {
      method, paths, path_params = full_path
        # Replace double //
        .gsub("//", "/")
        # Split on /
        .split("/")
        # Reformat positional parameters from ":xxx" to "{xxx}"
        .reduce({"", [] of String, [] of String}) { |acc, segment|
          method, path_array, params = acc
          if method.empty?
            {segment, path_array, params}
          elsif segment.starts_with? ':'
            param = segment[1..]
            path_array << "{#{param}}"
            params << param
            acc
          else
            path_array << "#{segment}"
            acc
          end
        }
      # Full stringified path.
      string_path = "/#{paths.join "/"}"
      # Key matching the registered controller operation.
      key = "#{route.controller}::#{route.action}"
      # Add the triplet if it matches the included methods & paths filters.
      if (
           (@included_methods.nil? || @included_methods.try &.includes?(method)) &&
           (@included_paths.nil? || @included_paths.try &.any? { |p| string_path.starts_with? p })
         )
        routes << {method, string_path, key, path_params}
      end
    }
    routes
  end
end
