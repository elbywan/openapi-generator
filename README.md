# openapi-generator

[![Build Status](https://travis-ci.org/elbywan/openapi-generator.svg?branch=master)](https://travis-ci.org/elbywan/openapi-generator)

#### Generate an [OpenAPI v3 compliant](https://swagger.io/specification/) yaml file declaratively from your web framework code.

Then serve it from a [Swagger UI](https://swagger.io/tools/swagger-ui/) instance.

## 💾 - Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  openapi-generator:
    github: elbywan/openapi-generator
```

2. Run `shards install`

## 📚 - Full Documentation

[**Please check this link for the full documentation.**](https://elbywan.github.io/openapi-generator/OpenAPI/Generator.html)

## ✨ - Minimal Working Example

**Important:** When using `Amber Framework` most of the OpenAPI values can be automatically inferred from the code!
Just include the [helper](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Helpers/Amber.html) in your `Controller` classes and use the provided macros.

```crystal
require "openapi-generator"

# The following example is using [Amber](https://amberframework.org/)
# but this library is compatible with any web framework.

require "amber"
require "openapi-generator/providers/amber"

# Optional: auto-serialize classes into openapi schema.
# Benefit: a typed Model class can then be used as the source of truth.
class Coordinates
  extend OpenAPI::Generator::Serializable

  def initialize(@lat, @long); end

  property lat  : Int32
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
```

Will produce an `./openapi.yaml` file with the following contents:

```yaml
---
openapi: 3.0.1
info:
  title: Server
  version: "1"
paths:
  /method/{id}:
    post:
      tags:
      - tag
      summary: A brief summary of the method.
      parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
        example: id
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Coordinates'
        required: true
      responses:
        "200":
          description: OK
        "404":
          description: Not Found.
    options:
      tags:
      - tag
      summary: A brief summary of the method.
      parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
        example: id
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Coordinates'
        required: true
      responses:
        "200":
          description: OK
        "404":
          description: Not Found.
components:
  schemas:
    Coordinates:
      required:
      - lat
      - long
      type: object
      properties:
        lat:
          type: integer
        long:
          type: integer
  responses: {}
  parameters: {}
  examples: {}
  requestBodies: {}
  headers: {}
  securitySchemes: {}
  links: {}
  callbacks: {}
```

## 🛠️ - Contributing

1. Fork it (<https://github.com/your-github-user/openapi-generator/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## 🤝 - Contributors

- [elbywan](https://github.com/your-github-user) - creator and maintainer
