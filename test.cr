require "./src/openapi-generator"

# The following example is using [Amber](https://amberframework.org/)
# but this library is compatible with any web framework.

require "amber"
require "./src/openapi-generator/providers/amber"

# Optional: auto-serialize classes into openapi schema.
class Coordinates
  extend OpenAPI::Generator::Serializable

  def initialize(@lat, @long); end

  property lat : Int32
  property long : Int32
end

# Annotate the methods that will appear in the openapi file.
class Controller < Amber::Controller::Base
  include OpenAPI::Generator::Controller

  @[OpenAPI(<<-YAML
    tags:
    - tag
    summary: A brief summary of the method.
    requestBody:
      required: true
      content:
        #{Schema.ref Coordinates}
    required: true
    responses:
      200:
        description: OK
      #{Schema.error 404}
  YAML
  )]
  def method
    # Some code…
  end
end

# Add the routes.
Amber::Server.configure do
  routes :api do
    post "/method/:id", Controller, :method
  end
end

# Generate the openapi file.

OpenAPI::Generator.generate(
  provider: OpenAPI::Generator::RoutesProvider::Amber.new
)
