module OpenAPI::Generator::Helpers::Lucky
  # :nodoc:
  BODY_LIST = {} of String => {::OpenAPI::RequestBody, Hash(String, ::OpenAPI::Schema)}

  # Extracts and serialize the body from the request and registers it in the OpenAPI operation.
  #
  # ```
  # # This will try to case the body as a SomeClass using the SomeClass.new method and assuming that the payload is a json.
  # body_as SomeClass, description: "Some payload.", content_type: "application/json", constructor: from_json
  # # The content_type, constructor and description can be omitted.
  # body_as SomeClass
  # ```
  macro body_as(type, description = nil, content_type = "application/json", constructor = :from_json)
    {% not_nil_type = type.resolve.union_types.reject { |t| t == Nil }[0] %}
    _body_as(
      request_body: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_request_body(
        description: {{description}},
        required: {{!type.resolve.nilable?}}
      ),
      schema: {{not_nil_type}}.to_openapi_schema,
      content_type: {{content_type}}
    )
    if %content = request.body.try &.gets_to_end
      ::{{not_nil_type}}.{{constructor.id}}(%content)
    end
  end

  # :nodoc:
  private macro _body_as(request_body, schema, content_type)
    {% body_list = ::OpenAPI::Generator::Helpers::Lucky::BODY_LIST %}
    {% method_name = "#{@type}" %}
    {% unless body_list.keys.includes? method_name %}
      {% body_list[method_name] = {request_body, {} of String => ::OpenAPI::Schema} %}
    {% end %}
    {% body_list[method_name][1][content_type] = schema %}
  end

  # Same as `body_as` but will raise if the body is missing or badly formatted.
  macro body_as!(*args, **named_args)
    %content = body_as({{*args}}, {{**named_args}})
    if !%content
      raise Lucky::Error.new "Missing body."
    end
    %content.not_nil!
  end

  # :nodoc:
  protected def self._init_openapi_request_body(description, required)
    ::OpenAPI::RequestBody.new(
      description: description,
      required: required,
      content: {} of String => ::OpenAPI::MediaType
    )
  end
end
