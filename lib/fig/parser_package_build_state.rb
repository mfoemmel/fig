require 'fig/package'
require 'fig/package_parse_error'
require 'fig/statement'
require 'fig/statement/archive'
require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/include'
require 'fig/statement/override'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/retrieve'
require 'fig/statement/set'

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

  def new_package_statement(directory, statements)
    return Fig::Package.new(
      descriptor.name,
      descriptor.version,
      directory,
      statements.elements.map do
        |statement|
        statement.to_package_statement(self)
      end
    )
  end

  def new_asset_statement(statement_class, keyword_node, url_node)
    return statement_class.new(
      node_location(keyword_node), source_description, url_node.value.text_value
    )
  end

  def new_retrieve_statement(keyword_node, variable_name_node, path_node)
    return Fig::Statement::Retrieve.new(
      node_location(keyword_node),
      source_description,
      variable_name_node.text_value,
      path_node.text_value
    )
  end

  def new_configuration_statement(keyword_node, name_node, statements)
    return Fig::Statement::Configuration.new(
      node_location(keyword_node),
      source_description,
      name_node.text_value,
      statements.elements.map do
        |statement|
        statement.to_config_statement(self)
      end
    )
  end

  def new_include_statement(keyword_node, descriptor_node)
    include_descriptor =
      Fig::Statement::Include.parse_descriptor(
        descriptor_node.text_value.strip,
        :source_description => node_location_description(descriptor_node),
        :validation_context => ' for an include statement'
      )

    return Fig::Statement::Include.new(
      node_location(keyword_node),
      source_description,
      include_descriptor,
      descriptor
    )
  end

  def new_override_statement(keyword_node, descriptor_node)
    override_descriptor =
      Fig::Statement::Override.parse_descriptor(
        descriptor_node.text_value.strip,
        :source_description => node_location_description(descriptor_node),
        :validation_context => ' for an override statement'
      )

    return Fig::Statement::Override.new(
      node_location(keyword_node),
      source_description,
      override_descriptor.name,
      override_descriptor.version
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

  def new_command_statement(keyword_node, command_node)
    return Fig::Statement::Command.new(
      node_location(keyword_node),
      source_description,
      command_node.value.text_value
    )
  end

  def raise_invalid_value_parse_error(keyword_node, value_node, description)
    raise Fig::PackageParseError.new(
      %Q<Invalid value for #{keyword_node.text_value} statement: "#{value_node.text_value}" #{description}#{node_location_description(value_node)}>
    )
  end
end
