require 'fig/package'
require 'fig/package_parse_error'
require 'fig/statement'
require 'fig/statement/archive'
require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/grammar_version'
require 'fig/statement/include'
require 'fig/statement/override'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/retrieve'
require 'fig/statement/set'

module Fig; end

# The state of a Package while it is being built by a Parser.
class Fig::ParserPackageBuildState
  def initialize(grammar_version, descriptor, source_description)
    @grammar_version    = grammar_version
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
      location[0], location[1], @source_description
    )
  end

  def new_package_statement(directory, grammar_node, statement_nodes)
    grammar_statement = nil
    if grammar_node && ! grammar_node.empty?
      grammar_statement = grammar_node.to_package_statement(self)
    else
      grammar_statement = Fig::Statement::GrammarVersion.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        0 # Grammar version
      )
    end
    statement_objects = [grammar_statement]

    statement_nodes.elements.each do
      |node|

      statement_objects << node.to_package_statement(self)
    end

    return Fig::Package.new(
      @descriptor.name,
      @descriptor.version,
      @descriptor.description,
      directory,
      statement_objects
    )
  end

  def new_grammar_version_statement(keyword_node, version_node)
    return Fig::Statement::GrammarVersion.new(
      node_location(keyword_node),
      @source_description,
      version_node.text_value.to_i
    )
  end

  def new_asset_statement(statement_class, keyword_node, location_node)
    raw_location = location_node.text_value

    tokenized_location =
      statement_class.validate_and_process_escapes_in_location(raw_location) do
        |error_description|

        raise_invalid_value_parse_error(
          keyword_node, location_node, 'URL/path', error_description
        )
      end

    location = tokenized_location.to_expanded_string
    need_to_glob = ! tokenized_location.single_quoted?
    return statement_class.new(
      node_location(keyword_node), @source_description, location, need_to_glob
    )
  end

  def new_retrieve_statement(keyword_node, variable_name_node, path_node)
    tokenized_path =
      Fig::Statement::Retrieve.tokenize_path(path_node.text_value) do
        |error_description|

        raise_invalid_value_parse_error(
          keyword_node, path_node, 'path', error_description
        )
      end

    return Fig::Statement::Retrieve.new(
      node_location(keyword_node),
      @source_description,
      variable_name_node.text_value,
      tokenized_path
    )
  end

  def new_configuration_statement(keyword_node, name_node, statements)
    statement_objects = statements.elements.map do
      |statement|

      statement.to_config_statement(self)
    end

    return Fig::Statement::Configuration.new(
      node_location(keyword_node),
      @source_description,
      name_node.text_value,
      statement_objects
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
      @source_description,
      include_descriptor,
      @descriptor
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
      @source_description,
      override_descriptor.name,
      override_descriptor.version
    )
  end

  def new_environment_variable_statement(
    statement_class, keyword_node, value_node
  )
    name = value = nil

    if @grammar_version == 0
      name, value = statement_class.parse_v0_name_value(value_node.text_value) {
        |description|
        raise_invalid_statement_parse_error(
          keyword_node, value_node, description
        )
      }
    else
      name, value = statement_class.parse_name_value(value_node.text_value) {
        |description|
        raise_invalid_statement_parse_error(
          keyword_node, value_node, description
        )
      }
    end

    return statement_class.new(
      node_location(keyword_node), @source_description, name, value
    )
  end

  def new_v0_command_statement(keyword_node, command_line_node)
    tokenized_command =
      Fig::Statement::Command.validate_and_process_escapes_in_argument(
        command_line_node.text_value
      ) {
        |description|
        raise_invalid_statement_parse_error(
          keyword_node, command_line_node, description
        )
      }

    return Fig::Statement::Command.new(
      node_location(keyword_node), @source_description, [tokenized_command]
    )
  end

  def new_v1_command_statement(keyword_node, command_line)
    return Fig::Statement::Command.new(
      node_location(keyword_node),
      @source_description,
      tokenize_v1_command_line(keyword_node, command_line)
    )
  end

  private

  def raise_invalid_value_parse_error(
    keyword_node, value_node, value_name, description
  )
    raise Fig::PackageParseError.new(
      %Q<Invalid #{value_name} for #{keyword_node.text_value} statement: "#{value_node.text_value}" #{description}#{node_location_description(value_node)}>
    )
  end

  def raise_invalid_statement_parse_error(keyword_node, value_node, description)
    raise Fig::PackageParseError.new(
      %Q<Invalid #{keyword_node.text_value} statement: "#{value_node.text_value}" #{description}#{node_location_description(value_node)}>
    )
  end

  def tokenize_v1_command_line(keyword_node, command_line)
    tokenized_command_line = []

    command_line.each do
      |argument_node|

      unparsed = argument_node.text_value
      next if unparsed.empty?

      tokenized_command_line <<
        Fig::Statement::Command.validate_and_process_escapes_in_argument(
          unparsed
        ) {
          |description|
          raise_invalid_statement_parse_error(
            keyword_node, argument_node, description
          )
        }
    end

    return tokenized_command_line
  end
end
