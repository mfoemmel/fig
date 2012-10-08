require 'stringio'

require 'fig/include_backtrace'
require 'fig/logging'
require 'fig/package'
require 'fig/repository_error'
require 'fig/statement/command'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/set'
require 'fig/user_input_error'
require 'fig/unparser'

module Fig; end

# Manages the program's metadata, including packages and environment
# variables, and sets things up for running commands (from "command"
# statements in definition files or from the command-line).
class Fig::RuntimeEnvironment
  # Note: when reading this code, understand that the word "retrieve" is a
  # noun and not a verb, e.g. "retrieve path" means the value of a retrieve
  # statement and not the action of retrieving a path.

  def initialize(repository, variables_override, working_directory_maintainer)
    @repository = repository
    @variables =
      variables_override || Fig::OperatingSystem.get_environment_variables()
    @retrieves = {}
    @packages = {}
    @working_directory_maintainer = working_directory_maintainer
  end

  # Returns the value of an envirionment variable
  def [](name)
    return @variables[name]
  end

  def variables
    return @variables.clone
  end

  # Indicates that the values from a particular environment variable path
  # should be copied to a local directory.
  def add_retrieve(retrieve_statement)
    name = retrieve_statement.variable
    if @retrieves.has_key?(name)
      Fig::Logging.warn \
        %q<About to overwrite "#{name}" retrieve path of "#{@retrieves[name].path}" with "#{retrieve_statement.path}".>
    end

    @retrieves[name] = retrieve_statement
    retrieve_statement.added_to_environment(true)

    return
  end

  def register_package(package)
    name = package.name

    if get_package(name)
      raise_repository_error(
        name.nil? \
          ? %Q<There is already a package with the name "#{name}".> \
          : %q<There is already an unnamed package.>,
        nil,
        package
      )
    end

    @packages[name] = package

    return
  end

  def get_package(name)
    return @packages[name]
  end

  def apply_config(package, config_name, backtrace)
    if package.applied_config_names.member?(config_name)
      return
    end

    new_backtrace = backtrace ||
      Fig::IncludeBacktrace.new(
        nil,
        Fig::PackageDescriptor.new(package.name, package.version, config_name)
      )

    config = package[config_name]

    Fig::Logging.debug("Applying #{package}:#{config_name}.")
    config.statements.each do
      |statement|
      apply_config_statement(package, statement, new_backtrace)
    end
    package.add_applied_config_name(config_name)

    return
  end

  def expand_command_line(base_package, base_config, descriptor, command_line)
    package, * =
      determine_package_for_execution(base_package, base_config, descriptor)

    expanded_command_line =
      command_line.map {
        |argument| expand_command_line_argument(argument, base_package)
      }

    @variables.with_environment { yield expanded_command_line }

    return
  end

  def expand_command_statement_from_config(
    base_package, base_config, descriptor, extra_arguments, &block
  )
    package, config_name =
      determine_package_for_execution(base_package, base_config, descriptor)

    command_statement = package[config_name].command_statement
    if command_statement
      expand_command(command_statement, extra_arguments, package, &block)
    else
      raise Fig::UserInputError.new(
        %Q<The "#{package.to_s}" package with the "#{config_name}" configuration does not contain a command.>
      )
    end

    return
  end

  # In order for this to work correctly, any Overrides need to be processed
  # before any other kind of Statement.  The Statement::Configuration class
  # guarantees that those come first in its set of Statements.
  def apply_config_statement(package, statement, backtrace)
    case statement
    when Fig::Statement::Path
      prepend_variable(package, statement, backtrace)
    when Fig::Statement::Set
      set_variable(package, statement, backtrace)
    when Fig::Statement::Include
      include_config(package, statement.descriptor, backtrace)
    when Fig::Statement::Override
      backtrace.add_override(statement)
    when Fig::Statement::Command
      # Skip - has no effect on environment.
    else
      text, * =
        Fig::Unparser.determine_version_and_unparse(statement, :emit_as_input)
      raise "Unexpected statement in a config block: #{text.strip}"
    end

    return
  end

  def include_config(starting_package, descriptor, backtrace)
    resolved_descriptor = nil

    # Check to see if this include has been overridden.
    if backtrace
      override_package_name = descriptor.name || starting_package.name
      override = backtrace.get_override(override_package_name)
      if override
        resolved_descriptor =
          Fig::PackageDescriptor.new(
            override_package_name, override, descriptor.config
          )
      end
    end
    resolved_descriptor ||= descriptor

    new_backtrace = Fig::IncludeBacktrace.new(backtrace, resolved_descriptor)
    package = lookup_package(
      resolved_descriptor.name || starting_package.name,
      resolved_descriptor.version,
      new_backtrace
    )
    apply_config(
      package,
      resolved_descriptor.config || Fig::Package::DEFAULT_CONFIG,
      new_backtrace
    )

    return
  end

  def check_unused_retrieves()
    @retrieves.keys().sort().each do
      |name|

      statement = @retrieves[name]
      if statement.loaded_but_not_referenced?
        text, * = Fig::Unparser.determine_version_and_unparse(
          [statement], :emit_as_input
        )
        Fig::Logging.warn \
          %Q<The #{name} variable was never referenced or didn't need expansion, so "#{text.strip}"#{statement.position_string} was ignored.>
      end
    end
  end

  private

  def set_variable(package, statement, backtrace)
    expanded_value = expand_variable_as_path_and_process_retrieves(
      statement, package, backtrace
    )
    name = statement.name
    @variables[name] = expanded_value

    if Fig::Logging.debug?
      value = statement.value
      expanded_message =
        expanded_value == value ? ''  \
                                : %Q< (expanded from "#{value}")>

      Fig::Logging.debug(
        %Q<Set #{name} to "#{expanded_value}"#{expanded_message}.>
      )
    end

    return
  end

  def prepend_variable(package, statement, backtrace)
    expanded_value = expand_variable_as_path_and_process_retrieves(
      statement, package, backtrace
    )
    name = statement.name
    @variables.prepend_variable(name, expanded_value)

    if Fig::Logging.debug?
      value = statement.value
      expanded_message =
        expanded_value == value ? ''  \
                                : %Q< ("#{value}" expanded to "#{expanded_value}")>

      Fig::Logging.debug(
        %Q<Prepending to #{name} resulted in "#{@variables[name]}"#{expanded_message}.>
      )
    end

    return
  end

  def lookup_package(name, version, backtrace)
    package = get_package(name)
    if package.nil?
      if not version
        raise_repository_error(
          "No version specified for #{name}.", backtrace, package
        )
      end

      package = @repository.get_package(
        Fig::PackageDescriptor.new(name, version, nil)
      )
      package.backtrace = backtrace
      @packages[name] = package
    elsif version && version != package.version
      raise_repository_error(
        "Version mismatch for package #{name} (#{version} vs #{package.version}).",
        backtrace,
        package
      )
    end

    return package
  end

  def determine_package_for_execution(base_package, base_config, descriptor)
    config_name =
      determine_config_to_executed(base_package, base_config, descriptor)

    package = nil

    if descriptor
      package_name = descriptor.name || base_package.name
      package      = lookup_package(
        package_name,
        descriptor.version,
        Fig::IncludeBacktrace.new(
          nil,
          Fig::PackageDescriptor.new(
            package_name, descriptor.version, config_name
          )
        )
      )
    else
      package = base_package
    end

    return [package, config_name]
  end

  def determine_config_to_executed(base_package, base_config, descriptor)
    return base_config if base_config

    if descriptor
      return descriptor.config if descriptor.config

      config_name = find_config_name_in_package_named(descriptor.name)
      return config_name if config_name
    end

    return find_config_name_in_package(base_package)
  end

  def find_config_name_in_package_named(name)
    package = get_package(name)
    if not package
      return Fig::Package::DEFAULT_CONFIG
    end

    return find_config_name_in_package(package)
  end

  def find_config_name_in_package(package)
    return package.primary_config_name || Fig::Package::DEFAULT_CONFIG
  end

  def expand_command(command_statement, extra_arguments, package)
    expanded_command_line =
      [ command_statement.command, extra_arguments ].flatten.map {
        |argument| expand_command_line_argument(argument, package)
      }

    if command_statement.command.size == 1
      expanded_command_line = [ expanded_command_line.join(' ') ]
    end

    @variables.with_environment { yield expanded_command_line }

    return
  end

  def expand_variable_as_path_and_process_retrieves(
    statement, package, backtrace
  )
    tokenized_value = statement.tokenized_value
    return tokenized_value.to_expanded_string { '@' } \
      unless package && package.name

    variable_value = tokenized_value.to_expanded_string { package.directory }

    return variable_value if not @retrieves.member?(statement.name)

    return retrieve_files(
      statement.name, variable_value, package, backtrace
    )
  end

  def retrieve_files(variable_name, variable_value, package, backtrace)
    check_source_existence(
      variable_name, variable_value, package, backtrace
    )

    destination_path =
      derive_retrieve_destination(variable_name, variable_value, package)

    @working_directory_maintainer.switch_to_package_version(
      package.name, package.version
    )
    @working_directory_maintainer.retrieve(variable_value, destination_path)

    return destination_path
  end

  def check_source_existence(
    variable_name, variable_value, package, backtrace
  )
    return if File.exists?(variable_value) || File.symlink?(variable_value)

    raise_repository_error(
      %Q<In #{package}, the #{variable_name} variable points to a path that does not exist ("#{variable_value}", after expansion).>,
      backtrace,
      package
    )
  end

  def derive_retrieve_destination(variable_name, variable_value, package)
    retrieve_path =
      get_retrieve_path_with_substitution(variable_name, package)

    # A '//' in the variable value tells us to preserve path
    # information after the '//' when doing a retrieve.
    if variable_value.include? '//'
      preserved_path = variable_value.split('//', -1).last

      return File.join(retrieve_path, preserved_path)
    end

    if File.directory?(variable_value)
      return retrieve_path
    end

    return File.join(retrieve_path, File.basename(variable_value))
  end

  def expand_command_line_argument(argument, starting_package)
    return argument.to_expanded_string() do
      |token|

      package_name = token.raw_value
      package = nil
      if package_name.empty?
        package = starting_package
      else
        package = get_package(package_name)
        if package.nil?
          raise_repository_error(
            %Q<Command-line referenced the "#{package_name}" package, which has not been referenced by any other package, so there's nothing to substitute with.>,
            nil,
            nil
          )
        end
      end

      if package && package.directory
        next package.directory
      end

      next '@'
    end
  end

  def get_retrieve_path_with_substitution(variable_name, package)
    retrieve_statement = @retrieves[variable_name]
    retrieve_statement.referenced(true)

    return retrieve_statement.path.gsub(/ \[package\] /x, package.name)
  end

  def raise_repository_error(message, backtrace, package)
    string_handle = StringIO.new
    backtrace.dump(string_handle) if backtrace

    if package && package.backtrace && package.backtrace != backtrace
      package.backtrace.dump(string_handle)
    end

    stacktrace = string_handle.string

    raise Fig::RepositoryError.new(
        message + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
    )
  end
end
