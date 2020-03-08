# Framework dependent implementations that should provide a list of routes mapped to a method that get executed on match.
module OpenAPI::Generator::RoutesProvider
end

# Base class for route providers.
abstract class OpenAPI::Generator::RoutesProvider::Base
  # Returns a list of `OpenAPI::Generator::RouteMapping`
  abstract def route_mappings : Array(RouteMapping)
end
