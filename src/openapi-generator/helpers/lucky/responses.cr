module OpenAPI::Generator::Helpers::Lucky
  # :nodoc:
  alias ControllerResponsesValue = Hash(Int32, {::OpenAPI::Response, Hash(String, ::OpenAPI::Schema)}) |
                                   Hash(Int32, {::OpenAPI::Response, Nil}) |
                                   Hash(Int32, Tuple(::OpenAPI::Response, Hash(String, Nil))) |
                                   Hash(Int32, Tuple(::OpenAPI::Response, Hash(String, ::OpenAPI::Schema) | Nil))

  # :nodoc:
  CONTROLLER_RESPONSES = {} of String => ControllerResponsesValue

  # Declare a json response.
  macro json(body, status = 200, description = nil, type = nil, schema = nil, headers = nil, links = nil)
    _controller_response(
      schema: {% if schema %}{{schema}}{% elsif type %}{{type}}.to_openapi_schema{% else %}nil{% end %},
      code: {{status}},
      response: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_response(
        description: {{description}},
        code: {{status}},
        headers: {{headers}},
        links: {{links}}
      )
    )
    self.json(body: {{body}}{% if type %}.as({{type}}){% end %}, status: {{status}})
  end

  # Declare a head response.
  macro head(status, description = nil, headers = nil, links = nil)
    _controller_response(
      schema: nil,
      code: {{status}},
      response: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_response(
        description: {{description}},
        code: {{status}},
        headers: {{headers}},
        links: {{links}}
      ),
      content_type: nil
    )
    self.head(status: {{status}})
  end

  # Declare an xml response.
  macro xml(body, status = 200, description = nil, type = String, schema = nil, headers = nil, links = nil)
    _controller_response(
      schema: {% if schema %}{{schema}}{% else %}{{type}}.to_openapi_schema{% end %},
      code: {{status}},
      response: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_response(
        description: {{description}},
        code: {{status}},
        headers: {{headers}},
        links: {{links}}
      ),
      content_type: "text/xml"
    )
    self.xml(body: {{body}}{% if type %}.as({{type}}){% end %}, status: {{status}})
  end

  # Declare a plain text response.
  macro plain_text(body, status = 200, description = nil, type = String, schema = nil, headers = nil, links = nil)
    _controller_response(
      schema: {% if schema %}{{schema}}{% else %}{{type}}.to_openapi_schema{% end %},
      code: {{status}},
      response: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_response(
        description: {{description}},
        code: {{status}},
        headers: {{headers}},
        links: {{links}}
      ),
      content_type: "text/plain"
    )
    self.plain_text(body: {{body}}{% if type %}.as({{type}}){% end %}, status: {{status}})
  end

  private macro _controller_response(schema, code, response, content_type = "application/json")
    {% controller_responses = ::OpenAPI::Generator::Helpers::Lucky::CONTROLLER_RESPONSES %}
    {% key = @type.stringify %}
    {% unless controller_responses[key] %}
      {% controller_responses[key] = {} of Int32 => Hash(String, {::OpenAPI::Response, Hash(String, ::OpenAPI::Schema)}) %}
    {% end %}
    {% unless controller_responses[key][code] %}
      {% controller_responses[key][code] = {response, {} of String => ::OpenAPI::Schema} %}
    {% end %}
    {% if content_type %}
      {% controller_responses[key][code][1][content_type] = schema %}
    {% else %}
      {% controller_responses[key][code][1] = nil %}
    {% end %}
  end

  # :nodoc:
  protected def self._init_openapi_response(description, headers, links, code)
    description = description || HTTP::Status.new(code).description || "#{code}"
    ::OpenAPI::Response.new(
      description: description,
      headers: headers,
      links: links,
      content: nil
    )
  end
end
