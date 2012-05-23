require 'fig/package_parse_error'
require 'fig/statement'

module Fig; end

class Fig::ParserPackageBuildState
  attr_reader :descriptor
  attr_reader :source_description

  def initialize(descriptor, source_description)
    @descriptor         = descriptor
    @source_description = source_description
  end

  def node_location(node)
    offset_from_start_of_file = node.interval.first
    input = node.input

    return [
      input.line_of(offset_from_start_of_file),
      input.column_of(offset_from_start_of_file)
    ]
  end

  # This method is necessary due to ruby v1.8 not allowing array splat
  # notation, i.e. Fig::Statement.position_description(*node_location(node),
  # source_description)
  def node_location_description(node)
    location = node_location(node)

    return Fig::Statement.position_description(
      location[0], location[1], source_description
    )
  end

  def new_environment_variable_statement(
    statement_class, keyword_node, value_node
  )
    name, value = statement_class.parse_name_value(value_node.text_value) {
      raise_invalid_value_parse_error(
        keyword_node,
        value_node,
        statement_class.const_get(:ARGUMENT_DESCRIPTION)
      )
    }
    return statement_class.new(
      node_location(keyword_node), source_description, name, value
    )
  end

  def raise_invalid_value_parse_error(keyword_node, value_node, description)
    raise Fig::PackageParseError.new(
      %Q<Invalid value for #{keyword_node.text_value} statement: "#{value_node.text_value}" #{description}#{node_location_description(value_node)}>
    )
  end
end
