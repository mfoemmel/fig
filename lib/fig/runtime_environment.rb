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
require 'fig/unparser/v0'

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
    name = retrieve_statement.var
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

  def execute_shell(command)
    @variables.with_environment do
      yield command.map{|arg| expand_command_line_argument(arg, nil, nil)}
    end

    return
  end

  def execute_config(base_package, base_config, descriptor, args, &block)
    config_name =
      determine_config_to_executed(base_package, base_config, descriptor)

    package = nil

    if descriptor
      name    = descriptor.name || base_package.name
      package = lookup_package(
        name,
        descriptor.version,
        Fig::IncludeBacktrace.new(
          nil,
          Fig::PackageDescriptor.new(name, descriptor.version, config_name)
        )
      )
    else
      package = base_package
    end

    command_statement = package[config_name].command_statement
    if command_statement
      execute_command(command_statement, args, package, nil, &block)
    else
      raise Fig::UserInputError.new(
        %Q<The "#{package.to_s}" package with the "#{config_name}" configuration does not contain a command.>
      )
    end

    return
  end

  # In order for this to work correctly, any Overrides need to be processed
  # before any other kind of Statement.  The Configuration class guarantees
  # that those come first in its set of Statements.
  def apply_config_statement(base_package, statement, backtrace)
    case statement
    when Fig::Statement::Path
      prepend_variable(base_package, statement.name, statement.value, backtrace)
    when Fig::Statement::Set
      set_variable(base_package, statement.name, statement.value, backtrace)
    when Fig::Statement::Include
      include_config(base_package, statement.descriptor, backtrace)
    when Fig::Statement::Override
      backtrace.add_override(statement)
    when Fig::Statement::Command
      # Skip - has no effect on environment.
    else
      unparser = Fig::Unparser::V0.new :emit_as_to_be_published
      text = unparser.unparse([statement]).strip
      raise "Unexpected statement in a config block: #{text}"
    end

    return
  end

  def include_config(base_package, descriptor, backtrace)
    resolved_descriptor = nil

    # Check to see if this include has been overridden.
    if backtrace
      override_package_name = descriptor.name || base_package.name
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
      resolved_descriptor.name || base_package.name,
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
        unparser = Fig::Unparser::V0.new :emit_as_to_be_published
        text = unparser.unparse([statement]).strip
        Fig::Logging.warn \
          %Q<The #{name} variable was never referenced or didn't need expansion, so "#{text}"#{statement.position_string} was ignored.>
      end
    end
  end

  private

  def set_variable(base_package, name, value, backtrace)
    expanded_value =
      expand_variable_as_path_and_process_retrieves(
        name, value, base_package, backtrace
      )
    @variables[name] = expanded_value

    if Fig::Logging.debug?
      expanded_message =
        expanded_value == value ? ''  \
                                : %Q< (expanded from "#{value}")>

      Fig::Logging.debug(
        %Q<Set #{name} to "#{expanded_value}"#{expanded_message}.>
      )
    end

    return
  end

  def prepend_variable(base_package, name, value, backtrace)
    expanded_value =
      expand_variable_as_path_and_process_retrieves(
        name, value, base_package, backtrace
      )
    @variables.prepend_variable(name, expanded_value)

    if Fig::Logging.debug?
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

  def execute_command(command_statement, args, package, backtrace)
    @variables.with_environment do
      argument =
        expand_command_line_argument(
          "#{command_statement.command} #{args.join(' ')}", backtrace, package
        )

      yield expand_at_signs_in_path(argument, package, backtrace).split(' ')
    end

    return
  end

  def expand_variable_as_path_and_process_retrieves(
    variable_name, variable_value, base_package, backtrace
  )
    return variable_value unless base_package && base_package.name

    variable_value =
      expand_at_signs_in_path(variable_value, base_package, backtrace)

    return variable_value if not @retrieves.member?(variable_name)

    return retrieve_files(
      variable_name, variable_value, base_package, backtrace
    )
  end

  def retrieve_files(variable_name, variable_value, base_package, backtrace)
    check_source_existence(
      variable_name, variable_value, base_package, backtrace
    )

    destination_path =
      derive_retrieve_destination(variable_name, variable_value, base_package)

    @working_directory_maintainer.switch_to_package_version(
      base_package.name, base_package.version
    )
    @working_directory_maintainer.retrieve(variable_value, destination_path)

    return destination_path
  end

  def check_source_existence(
    variable_name, variable_value, base_package, backtrace
  )
    return if File.exists?(variable_value) || File.symlink?(variable_value)

    raise_repository_error(
      %Q<In #{base_package}, the #{variable_name} variable points to a path that does not exist ("#{variable_value}", after expansion).>,
      backtrace,
      base_package
    )
  end

  def derive_retrieve_destination(variable_name, variable_value, base_package)
    retrieve_path =
      get_retrieve_path_with_substitution(variable_name, base_package)

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

  def expand_at_signs_in_path(path, base_package, backtrace)
    expanded_path =
      replace_at_signs_with_package_references(path, base_package)
    check_for_bad_escape(expanded_path, path, base_package, backtrace)

    return collapse_backslashes_for_escaped_at_signs(expanded_path)
  end

  def replace_at_signs_with_package_references(arg, base_package)
    return arg.gsub(
      %r<
        (?: ^ | \G)           # Zero-width anchor.
        ( [^\\@]* (?:\\{2})*) # An even number of leading backslashes
        \@                    # The package indicator
      >x
    ) do |match|
      backslashes = $1 || ''
      backslashes + base_package.directory
    end
  end

  def expand_command_line_argument(arg, backtrace, package)
    package_substituted = expand_named_package_references(arg, backtrace)
    check_for_bad_escape(package_substituted, arg, package, backtrace)

    return collapse_backslashes_for_escaped_at_signs(package_substituted)
  end

  def expand_named_package_references(arg, backtrace)
    return arg.gsub(
      # TODO: Refactor package name regex into PackageDescriptor constant.
      %r<
        (?: ^ | \G)           # Zero-width anchor.
        ( [^\\@]* (?:\\{2})*) # An even number of leading backslashes
        \@                    # The package indicator
        ( [a-zA-Z0-9_.-]+ )   # Package name
      >x
    ) do |match|
      backslashes = $1 || ''
      package_name = $2
      package = get_package(package_name)
      if package.nil?
        raise_repository_error(
          %Q<Command-line referenced the "#{package_name}" package, which has not been referenced by any other package, so there's nothing to substitute with.>,
          backtrace,
          nil
        )
      end
      backslashes + package.directory
    end
  end

  # The value is expected to have had any @ substitution already done, but
  # collapsing of escapes not done yet.
  def check_for_bad_escape(substituted, original, package, backtrace)
    if substituted =~ %r<
      (?: ^ | [^\\])  # Start of line or non backslash
      (?: \\{2})*     # Even number of backslashes (including zero)
      ( \\ [^\\@] )   # A bad escape
    >x
      raise_repository_error(
        %Q<Unknown escape "#{$1}" in "#{original}">, backtrace, package
      )
    end

    return
  end

  # After @ substitution, we need to get rid of the backslashes in front of
  # any escaped @ signs.
  def collapse_backslashes_for_escaped_at_signs(string)
    return string.gsub(%r< \\ ([\\@]) >x, '\1')
  end

  def get_retrieve_path_with_substitution(name, base_package)
    retrieve_statement = @retrieves[name]
    retrieve_statement.referenced(true)

    return retrieve_statement.path.gsub(/ \[package\] /x, base_package.name)
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
