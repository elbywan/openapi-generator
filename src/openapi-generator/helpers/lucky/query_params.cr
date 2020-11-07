module OpenAPI::Generator::Helpers::Lucky
  # :nodoc:
  QP_LIST = {} of String => Array(::OpenAPI::Parameter)

  # Declare a query parameter.
  macro param(declaration, description = nil, multiple = false, schema = nil, **args)
    {% name = declaration.var.stringify %}
    {% type = declaration.type ? declaration.type.resolve : String %}
    {% type = type.union_types.reject { |t| t == Nil }[0] %}
    _append_query_param(
      name: {{name}},
      param: ::OpenAPI::Generator::Helpers::Lucky._init_openapi_parameter(
        name: {{name}},
        "in": "query",
        required: {{ !declaration.type.resolve.nilable? }},
        schema: {% if schema %}{{ schema }}{% elsif multiple %}::OpenAPI::Schema.new(
          type: "array",
          items: {{type}}.to_openapi_schema,
        ){% else %}{{type}}.to_openapi_schema{% end %},
        description: {{description}},
        {{**args}}
      ),
      required: true,
      multiple: {{multiple}}
    )
    param(type_declaration: {{declaration}})
  end

  # :nodoc:
  protected def self._init_openapi_parameter(**args)
    ::OpenAPI::Parameter.new(**args)
  end

  # :nodoc:
  private macro _append_query_param(name, param, required = true, multiple = false)
    {% qp_list = ::OpenAPI::Generator::Helpers::Lucky::QP_LIST %}
    {% key = "#{@type}" %}
    {% unless qp_list.keys.includes? key %}
      {% qp_list[key] = [] of ::OpenAPI::Parameter %}
    {% end %}
    {% qp_list[key] << param %}
  end
end
