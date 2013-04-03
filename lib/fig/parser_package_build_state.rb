require 'fig/logging'
require 'fig/package'
require 'fig/package_parse_error'
require 'fig/statement'
require 'fig/statement/archive'
require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/desired_install_path'
require 'fig/statement/grammar_version'
require 'fig/statement/include'
require 'fig/statement/include_file'
require 'fig/statement/override'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/retrieve'
require 'fig/statement/set'
require 'fig/statement/use_desired_install_paths'
require 'fig/string_tokenizer'

module Fig; end

# The state of a Package while it is being built by a Parser.
class Fig::ParserPackageBuildState
  def initialize(
    grammar_version, descriptor, source_description, use_desired_install_paths
  )
    @grammar_version            = grammar_version
    @descriptor                 = descriptor
    @source_description         = source_description
    @use_desired_install_paths  = use_desired_install_paths
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

  def new_package_statement(unparsed_package, grammar_node, statement_nodes)
    statement_objects =
      convert_nodes_to_statement_objects(grammar_node, statement_nodes)
    working_directory, include_file_base_directory =
      derive_directories_for_package(unparsed_package, statement_objects)

    package = Fig::Package.new(
      @descriptor.name,
      @descriptor.version,
      @descriptor.description,
      working_directory,
      include_file_base_directory,
      statement_objects,
      false,
    )
    package.unparsed_text = unparsed_package.unparsed_text

    return package
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

  def new_desired_install_path_statement(keyword_node, path_node)
    path_text = path_node.text_value
    tokenized_path = Fig::StringTokenizer.new.tokenize(path_text) do
      |description|

      raise Fig::PackageParseError.new(
        %Q<Invalid desired-install-path statement: "#{path_text}" #{description}#{node_location_description(path_node)}>
      )
    end

    return Fig::Statement::DesiredInstallPath.new(
      node_location(keyword_node),
      @source_description,
      tokenized_path.to_expanded_string,
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

  def new_use_desired_install_paths_statement(keyword_node)
    return Fig::Statement::UseDesiredInstallPaths.new(
      node_location(keyword_node), @source_description,
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
      nil,
      @descriptor
    )
  end

  def new_include_file_statement(keyword_node, path_node, config_name_node)
    path, config_name =
      Fig::Statement::IncludeFile.validate_and_process_raw_path_and_config_name(
        path_node.text_value,
        config_name_node.nil? ? nil : config_name_node.text_value,
      ) do
        |description|

        value_text = path_node.text_value
        if ! config_name_node.nil?
          value_text << ':'
          value_text << config_name_node.text_value
        end

        raise Fig::PackageParseError.new(
          %Q<Invalid include-file statement: "#{value_text}" #{description}#{node_location_description(path_node)}>
        )
      end

    return Fig::Statement::IncludeFile.new(
      node_location(keyword_node),
      @source_description,
      path,
      config_name,
      @descriptor,
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

  def convert_nodes_to_statement_objects(grammar_node, statement_nodes)
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

    return statement_objects
  end

  def derive_directories_for_package(unparsed_package, statement_objects)
    # Don't worry about multiple, that will be checked later.  We just care
    # whether there is one.
    install_path_statement =
      (
        statement_objects.select {
          |statement| statement.is_a? Fig::Statement::DesiredInstallPath
        }
      ).first
    if ! install_path_statement || ! @use_desired_install_paths
      if ! @use_desired_install_paths && install_path_statement
        Fig::Logging.warn(
          "#{@descriptor.to_string} has a desired-install-path statement#{install_path_statement.position_string}, but installation to absolute paths is not permitted by a use-desired-install-paths statement in the base config."
        )
      end

      return [
        unparsed_package.working_directory,
        unparsed_package.include_file_base_directory
      ]
    end

    include_file_base_directory = install_path_statement.path
    if (
      unparsed_package.working_directory            !=
      unparsed_package.include_file_base_directory
    )
      include_file_base_directory = unparsed_package.include_file_base_directory
    end

    return [install_path_statement.path, include_file_base_directory]
  end

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
