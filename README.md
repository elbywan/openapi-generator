# openapi-generator

[![Build Status](https://travis-ci.org/elbywan/openapi-generator.svg?branch=master)](https://travis-ci.org/elbywan/openapi-generator)

#### Generate an [OpenAPI v3 compliant](https://swagger.io/specification/) yaml file declaratively from your web framework code.

Then serve it from a [Swagger UI](https://swagger.io/tools/swagger-ui/) instance.

## Setup

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  openapi-generator:
    github: elbywan/openapi-generator
```

2. Run `shards install`

3. Require the shard

```crystal
require "openapi-generator"
```

## API Documentation

[**🔗 Full API documentation.**](https://elbywan.github.io/openapi-generator/OpenAPI/Generator.html)

## Concepts

### Declare Operations

*From the [OpenAPI specification](https://swagger.io/docs/specification/paths-and-operations/).*

> In OpenAPI terms, paths are endpoints (resources), such as /users or /reports/summary/, that your API exposes, and operations are the HTTP methods used to manipulate these paths, such as GET, POST or DELETE.

#### Method based (`Amber`, `Spider-gazelle`)

Use the `@[OpenAPI]` annotation with a `yaml` encoded string argument.

```crystal
class Controller
  include OpenAPI::Generator::Controller

  @[OpenAPI(<<-YAML
    tags:
      - tag
    summary:
      A brief summary.
  YAML
  )]
  def handler
    # …
  end
end
```

#### Class based (`Lucky`)

Use the `open_api` macro with a `yaml` encoded string argument.

```crystal
class Handler
  include OpenAPI::Generator::Controller

  open_api <<-YAML
    tags:
      - tag
    summary:
      A brief summary.
  YAML

  route do
    # …
  end
end
```

#### Shorthands

The [`OpenAPI::Generator::Controller::Schema`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html) class exposes shorthands for common OpenAPI yaml constructs.

```crystal
# Example:

open_api <<-YAML
  tags:
    - tag
  summary:
    A brief summary.
  parameters:
    #{Schema.qp name: "id", description: "Filter by id.", required: true}
  responses:
    200:
      description: OK
    #{Schema.error 404}
YAML
```

- [`Schema.error(code, message = nil)`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#error(code,message=nil)-instance-method)
- [`Schema.header(name, description, type = "string")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#header(name,description,type=%22string%22)-instance-method)
- [`Schema.header_param(name, description, *, required = false, type = "string")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#header_param(name,description,*,required=false,type=%22string%22)-instance-method)
- [`Schema.qp(name, description, *, required = false, type = "string")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#qp(name,description,*,required=false,type=%22string%22)-instance-method)
- [`Schema.ref(schema, *, content_type = "application/json")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#ref(schema,*,content_type=%22application/json%22)-instance-method)
- [`Schema.ref_array(schema, *, content_type = "application/json")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#ref_array(schema,*,content_type=%22application/json%22)-instance-method)
- [`Schema.string_array(*, content_type = "application/json")`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/Controller/Schema.html#string_array(*,content_type=%22application/json%22)-instance-method)

### `openapi.yaml` Generation

**After** declaring the operations, you can call `OpenAPI::Generator.generate` to generate the `openapi.yaml` file that will describe your server.

**Note**: An [`OpenAPI::Generator::RoutesProvider::Base`](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/RoutesProvider.html) implementation must be provided. A `RoutesProvider` is responsible from extracting the [server routes and mapping these routes with the declared operations](https://elbywan.github.io/openapi-generator/OpenAPI/Generator/RouteMapping.html) in order to produce the final openapi file.

```crystal
OpenAPI::Generator.generate(
  provider: provider
)
```

Currently, the [Amber](https://amberframework.org/), [Lucky](https://luckyframework.org), [Spider-gazelle](https://spider-gazelle.net/) providers are included out of the box.

<details><summary><strong>Amber</strong></summary>
<p>

```crystal
# Amber provider
require "openapi-generator/providers/amber"

OpenAPI::Generator.generate(
  provider: OpenAPI::Generator::RoutesProvider::Amber.new
)
```

</p></details>

<details><summary><strong>Lucky</strong></summary>
<p>

```crystal
# Lucky provider
require "openapi-generator/providers/lucky"

OpenAPI::Generator.generate(
  provider: OpenAPI::Generator::RoutesProvider::Lucky.new
)
```

</p></details>

<details><summary><strong>Spider-gazelle</strong></summary>
<p>

```crystal
# Spider-gazelle provider
require "openapi-generator/providers/action-controller"

OpenAPI::Generator.generate(
  provider: OpenAPI::Generator::RoutesProvider::ActionController.new
)
```

</p></details>

<details><summary><strong>Custom</strong></summary>

```crystal
# Or define your own…
class MockProvider < OpenAPI::Generator::RoutesProvider::Base
  def route_mappings : Array(OpenAPI::Generator::RouteMapping)
    [
      {"get", "/{id}", "HelloController::index", ["id"]},
      {"head", "/{id}", "HelloController::index", ["id"]},
      {"options", "/{id}", "HelloController::index", ["id"]},
    ]
  end
end

OpenAPI::Generator.generate(
  provider: MockProvider.new
)
```

</p>
</details>

The `.generate` method accepts additional options:

```crystal
OpenAPI::Generator.generate(
  provider: provider,
  options: {
    # Customize output path
    output: Path[Dir.current] / "public" / "openapi.yaml"
  },
  # Customize openapi.yaml base document fields
  base_document: {
    info: {
        title:   "My Server",
        version: "v0.1",
      }
  }
)
```

### Schema Serialization

Adding `extend OpenAPI::Generator::Serializable` to an existing class or struct will:
- register the object as a reference making it useable anywhere in the openapi file
- add a `.to_openapi_schema` method that will produce the associated `OpenAPI::Schema`

```crystal
class Coordinates
  extend OpenAPI::Generator::Serializable

  def initialize(@lat, @long); end

  property lat  : Int32
  property long : Int32
end

# Produces an OpenAPI::Schema reference.
puts Coordinates.to_openapi_schema.to_yaml
# ---
# allOf:
# - $ref: '#/components/schemas/Coordinates'
```

And in the `openapi.yaml` file that gets generated, the `Coordinates` object is registered as a `/components/schemas/Coordinates` reference.

```yaml
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
```

#### In practice

The object can now be referenced from the yaml declaration…

```crystal
class Controller
  include OpenAPI::Generator::Controller

  @[OpenAPI(<<-YAML
    requestBody:
      required: true
      content:
        #{Schema.ref Coordinates}
  YAML
  )]
  def method
    # …
  end
end
```

…and it can be used by the schema inference (more on that later).

```crystal
class Hello::Index < Lucky::Action
  include OpenAPI::Generator::Helpers::Lucky

  disable_cookies
  default_format :text

  post "/hello" do
    coordinates = body_as Coordinates?, description: "Some coordinates."

    plain_text "Hello (#{coordinates.x}, #{coordinates.y})"
  end
end
```

#### Customize fields

Use the `@[OpenAPI::Field]` annotation to add properties to the fields.

```crystal
class MyClass
  extend OpenAPI::Generator::Serializable

  # Ignore the field. It will not appear in the schema.
  @[OpenAPI::Field(ignore: true)]
  property ignored_field

  # Enforce a type in the schema and disregard the crystal type.
  @[OpenAPI::Field(type: String)]
  property str_field : Int32

  # Add an example that will appear in swagger for instance.
  @[OpenAPI::Field(example: "an example value")]
  property some_field : String

  # Will not appear in POST / PUT/ PATCH requests body.
  @[OpenAPI::Field(read_only: true)]
  property read_only_field : String

  # Will only appear in POST / PUT / PATCH requests body.
  @[OpenAPI::Field(write_only: true)]
  property write_only_field : String
end
```

## Inference (Optional)

`openapi-generator` can infer some schema properties from the code, removing the need to declare it with yaml.

**Can be inferred:**
- Request body
- Response body
- Query parameters

**Supported Frameworks:**

<details><summary><strong>Amber</strong></summary>

```crystal
require "openapi-generator/helpers/amber"

# …declare routes and operations… #

# Before calling .generate you need to bootstrap the amber inference:
OpenAPI::Generator::Helpers::Amber.bootstrap
```

#### Example

```crystal
require "openapi-generator/helpers/amber"

class Coordinates
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@x, @y); end

  property x  : Int32
  property y  : Int32
end

class CoordinatesController < Amber::Controller::Base
  include ::OpenAPI::Generator::Controller
  include ::OpenAPI::Generator::Helpers::Amber

  @[OpenAPI(
    <<-YAML
      summary: Adds up a Coordinate object and a number.
    YAML
  )]
  def add
    # Infer query parameter.
    add = query_params("add", description: "Add this number to the coordinates.").to_i32
    # Infer body as a Coordinate json payload.
    coordinates = body_as(::Coordinates, description: "Some coordinates").not_nil!
    coordinates.x += add
    coordinates.y += add

    # Infer responses.
    respond_with 200, description: "Returns a Coordinate object with the number added up." do
      json coordinates, type: ::Coordinates
      xml %(<coordinate x="#{coordinates.x}" y="#{coordinates.y}"></coordinate>), type: String
      text "Coordinates (#{coordinates.x}, #{coordinates.y})", type: String
    end
  end
end
```

#### API

`openapi-generator` overload existing or adds similar methods and macros to intercept calls and infer schema properties.

*Query parameters*

- `macro query_params(name, description, multiple = false, schema = nil, **args)`
- `macro query_params?(name, description, multiple = false, schema = nil, **args)`

*Body*

- `macro body_as(type, description = nil, content_type = "application/json", constructor = :from_json)`

*Responses*

- `macro respond_with(code = 200, description = nil, headers = nil, links = nil, &)`

- `macro json(body, type = nil, schema = nil)`
- `macro xml(body, type = nil, schema = nil)`
- `macro txt(body, type = nil, schema = nil)`
- `macro text(body, type = nil, schema = nil)`
- `macro html(body, type = nil, schema = nil)`
- `macro js(body, type = nil, schema = nil)`

</p></details>

<details><summary><strong>Spider-gazelle</strong></summary>

```crystal
require "openapi-generator/helpers/action-controller"

# …declare routes and operations… #

# Before calling .generate you need to bootstrap the spider-gazelle inference:
OpenAPI::Generator::Helpers::ActionController.bootstrap
```

#### Example

```crystal
require "openapi-generator/helpers/action-controller"

class Coordinates
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@x, @y); end

  property x  : Int32
  property y  : Int32
end

class CoordinatesController < ActionController::Controller::Base
  include ::OpenAPI::Generator::Controller
  include ::OpenAPI::Generator::Helpers::ActionController

  @[OpenAPI(
    <<-YAML
      summary: Adds up a Coordinate object and a number.
    YAML
  )]
  def add
    # Infer query parameter.
    add = param add : Int32, description: "Add this number to the coordinates."
    # Infer body as a Coordinate json payload.
    coordinates = body_as(::Coordinates, description: "Some coordinates").not_nil!
    coordinates.x += add
    coordinates.y += add

    # Infer responses.
    respond_with 200, description: "Returns a Coordinate object with the number added up." do
      json coordinates, type: ::Coordinates
      xml %(<coordinate x="#{coordinates.x}" y="#{coordinates.y}"></coordinate>), type: String
      text "Coordinates (#{coordinates.x}, #{coordinates.y})", type: String
    end
  end
end
```

#### API

`openapi-generator` overload existing or adds similar methods and macros to intercept calls and infer schema properties.

*Query parameters*

- `macro param(declaration, description, multiple = false, schema = nil, **args)`

*Body*

- `macro body_as(type, description = nil, content_type = "application/json", constructor = :from_json)`

*Responses*

- `macro respond_with(code = 200, description = nil, headers = nil, links = nil, &)`
  - `macro json(body, type = nil, schema = nil)`
  - `macro xml(body, type = nil, schema = nil)`
  - `macro txt(body, type = nil, schema = nil)`
  - `macro text(body, type = nil, schema = nil)`
  - `macro html(body, type = nil, schema = nil)`
  - `macro js(body, type = nil, schema = nil)`

-  `macro render(status_code = :ok, head = Nop, json = Nop, yaml = Nop, xml = Nop, html = Nop, text = Nop, binary = Nop, template = Nop, partial = Nop, layout = nil, description = nil, headers = nil, links = nil, type = nil, schema = nil)`

</p>
</details>

<details><summary><strong>Lucky</strong></summary>
<p>

```crystal
require "openapi-generator/helpers/lucky"

# …declare routes and operations… #

# Before calling .generate you need to bootstrap the lucky inference:
OpenAPI::Generator::Helpers::Lucky.bootstrap
```

**Important:** In your Actions, use `include OpenAPI::Generator::Helpers::Lucky` instead of `include OpenAPI::Generator::Controller`.

#### Example

```crystal
require "openapi-generator/helpers/lucky"

class Coordinates
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable

  def initialize(@x, @y); end

  property x  : Int32
  property y  : Int32
end

class Api::Coordinates::Create < Lucky::Action
  # `OpenAPI::Generator::Controller` is included alongside `OpenAPI::Generator::Helpers::Lucky`.
  include OpenAPI::Generator::Helpers::Lucky

  disable_cookies
  default_format :json

  # Infer query parameter.
  param add : Int32, description: "Add this number to the coordinates."

  def action
    # Infer body as a Coordinate json payload.
    coordinates = body_as! ::Coordinates, description: "Some coordinates"
    coordinates.x += add
    coordinates.y += add

    # Infer responses.
    if json?
      json coordinates, type: ::Coordinates
    elsif  xml?
      xml %(<coordinate x="#{coordinates.x}" y="#{coordinates.y}"></coordinate>), schema: OpenAPI::Schema.new(type: "string")
    elsif plain_text?
      plain_text "Coordinates (#{coordinates.x}, #{coordinates.y})"
    else
      head 406
    end
  end

  route { action }
end
```

#### API

`openapi-generator` overload existing or adds similar methods and macros to intercept calls and infer schema properties.

*Query parameters*

- `macro param(declaration, description = nil, schema = nil, **args)`

*Body*

- `macro body_as(type, description = nil, content_type = "application/json", constructor = :from_json)`
- `macro body_as!(type, description = nil, content_type = "application/json", constructor = :from_json)`

*Responses*

- `macro json(body, status = 200, description = nil, type = nil, schema = nil, headers = nil, links = nil)`
- `macro head(status, description = nil, headers = nil, links = nil)`
- `macro xml(body, status = 200, description = nil, type = String, schema = nil, headers = nil, links = nil)`
- `macro plain_text(body, status = 200, description = nil, type = String, schema = nil, headers = nil, links = nil)`

</p>
</details>

## Swagger UI

The method to serve a Swagger UI instance depends on which framework you are using.

1. Setup a static file handler. (ex: [Lucky](https://luckyframework.org/guides/http-and-routing/http-handlers#built-in-handlers), [Amber](https://docs.amberframework.org/amber/guides/routing/pipelines))
2. Download [the latest release archive](https://github.com/swagger-api/swagger-ui/releases)
3. Move the `/dist` folder to your static file directory.
4. Edit the `index.html` file and change the assets and `openapi.yaml` paths.

## Contributing

1. Fork it (<https://github.com/your-github-user/openapi-generator/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Specs

Do **not** run `crystal specs` without arguments. It will not compile due to global cookies and session class overrides issues between Amber & Lucky.

To test the project, have a look at the `.travis.yml` file which contains the right command to use:

```sh
crystal spec ./spec/core && \
crystal spec ./spec/amber && \
crystal spec ./spec/lucky && \
crystal spec ./spec/spider-gazelle
```

## Contributors

- [elbywan](https://github.com/elbywan) - creator and maintainer
- [dukeraphaelng](https://github.com/dukeraphaelng)