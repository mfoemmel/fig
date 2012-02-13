require 'stringio'

require 'fig/backtrace'
require 'fig/logging'
require 'fig/package'
require 'fig/repositoryerror'
require 'fig/statement/command'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/set'
require 'fig/userinputerror'

module Fig
  # Manages the program's metadata, including packages and environment
  # variables, and sets things up for running commands (from "command"
  # statements in configuration files).
  class Environment
    DEFAULT_VERSION_NAME = 'current'

    def initialize(repository, variables_override, retriever)
      @repository = repository
      @variables = variables_override || OperatingSystem.get_environment_variables
      @retrieve_vars = {}
      @packages = {}
      @retriever = retriever
    end

    # Returns the value of an envirionment variable
    def [](name)
      return @variables[name]
    end

    def variables
      return @variables.clone
    end

    # Indicates that the values from a particular envrionment variable path
    def add_retrieve(name, path)
      @retrieve_vars[name] = path

      return
    end

    def register_package(package)
      name = package.name

      if get_package(name)
        Logging.fatal %Q<There is already a package with the name "#{name}".>
        raise RepositoryError.new
      end

      @packages[name] = package

      return
    end

    def get_package(name)
      return @packages[name]
    end

    def packages
      return @packages.values
    end

    def apply_config(package, config_name, backtrace)
      if package.applied_config_names.member?(config_name)
        return
      end
      new_backtrace = backtrace

      config = package[config_name]
      config.statements.each { |stmt| apply_config_statement(package, stmt, new_backtrace) }
      package.add_applied_config_name(config_name)

      return
    end

    def execute_shell(command)
      with_environment do
        yield command.map{|arg| expand_command_line_argument(arg)}
      end

      return
    end

    def execute_command(command, args, package)
      with_environment do
        argument =
          expand_command_line_argument(
            "#{command.command} #{args.join(' ')}"
          )

        yield expand_path(argument, package).split(' ')
      end

      return
    end

    def find_config_name_in_package(name)
      package = get_package(name)
      if not package
        return Package::DEFAULT_CONFIG
      end

      return package.primary_config_name || Package::DEFAULT_CONFIG
    end

    def execute_config(base_package, descriptor, args, &block)
      config_name =
        descriptor.config || find_config_name_in_package(descriptor.name)

      name = descriptor.name || base_package.name
      package = lookup_package(
        name,
        descriptor.version,
        Backtrace.new(
          nil,
          PackageDescriptor.new(name, descriptor.version, config_name)
        )
      )

      command = package[config_name].command
      if command
        execute_command(command, args, package, &block)
      else
        raise UserInputError.new(%Q<The "#{package.to_s}" package with the "#{config_name}" configuration does not contain a command.>)
      end

      return
    end

    def apply_config_statement(base_package, statement, backtrace)
      case statement
      when Statement::Path
        prepend_variable(base_package, statement.name, statement.value)
      when Statement::Set
        set_variable(base_package, statement.name, statement.value)
      when Statement::Include
        include_config(
          base_package, statement.descriptor, statement.overrides, backtrace
        )
      when Statement::Command
        # ignore
      else
        fail "Unexpected statement: #{statement}"
      end

      return
    end

    def include_config(base_package, descriptor, overrides, backtrace)
      resolved_descriptor = nil

      # Check to see if this include has been overridden.
      if backtrace
        override = backtrace.get_override(
          descriptor.name || base_package.name
        )
        if override
          resolved_descriptor =
            PackageDescriptor.new(
              descriptor.name, override, descriptor.config
            )
        end
      end
      resolved_descriptor ||= descriptor

      new_backtrace = Backtrace.new(backtrace, resolved_descriptor)
      overrides.each do |override|
        new_backtrace.add_override(override.package_name, override.version)
      end
      package = lookup_package(
        resolved_descriptor.name || base_package.name,
        resolved_descriptor.version,
        new_backtrace
      )
      apply_config(
        package,
        resolved_descriptor.config || Package::DEFAULT_CONFIG,
        new_backtrace
      )

      return
    end

    private

    def set_variable(base_package, name, value)
      @variables[name] = expand_and_retrieve_variable_value(base_package, name, value)

      return
    end

    def prepend_variable(base_package, name, value)
      value = expand_and_retrieve_variable_value(base_package, name, value)
      @variables.prepend_variable(name, value)

      return
    end

    def with_environment
      begin
        @variables.set_system_environment_variables
        yield
      ensure
        @variables.reset_system_environment_variables
      end

      return
    end

    def lookup_package(name, version, backtrace)
      package = get_package(name)
      if package.nil?
        if not version
          Logging.fatal "No version specified for #{name}."
          raise RepositoryError.new
        end

        package = @repository.get_package(
          PackageDescriptor.new(name, version, nil)
        )
        package.backtrace = backtrace
        @packages[name] = package
      elsif version && version != package.version
        string_handle = StringIO.new
        backtrace.dump(string_handle) if backtrace
        package.backtrace.dump(string_handle) if package.backtrace
        stacktrace = string_handle.string
        Logging.fatal                           \
            "Version mismatch: #{name}" \
          + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
        raise RepositoryError.new
      end

      return package
    end

    # Replace @ symbol with the package's directory, "[package]" with the
    # package name.
    def expand_and_retrieve_variable_value(base_package, name, value)
      return value unless base_package && base_package.name

      file = expand_path(value, base_package)

      if @retrieve_vars.member?(name)
        # A '//' in the source file's path tells us to preserve path
        # information after the '//' when doing a retrieve.
        if file.split('//').size > 1
          preserved_path = file.split('//').last
          target = File.join(
            translate_retrieve_variables(base_package, name),
            preserved_path
          )
        else
          target = File.join(
            translate_retrieve_variables(base_package, name)
          )
          if not File.directory?(file)
            target = File.join(target, File.basename(file))
          end
        end
        @retriever.with_package_version(
          base_package.name, base_package.version
        ) do
          @retriever.retrieve(file, target)
        end
        file = target
      end

      return file
    end

    def expand_path(path, base_package)
      expanded_path = expand_at_sign_package_references(path, base_package)
      check_for_bad_escape(expanded_path, path)

      return expanded_path.gsub(%r< \\ ([\\@]) >x, '\1')
    end

    def expand_at_sign_package_references(arg, base_package)
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

      return
    end

    def expand_command_line_argument(arg)
      package_substituted = expand_named_package_references(arg)
      check_for_bad_escape(package_substituted, arg)

      return package_substituted.gsub(%r< \\ ([\\@]) >x, '\1')
    end

    def expand_named_package_references(arg)
      return arg.gsub(
        %r<
          (?: ^ | \G)           # Zero-width anchor.
          ( [^\\@]* (?:\\{2})*) # An even number of leading backslashes
          \@                    # The package indicator
          ( [a-zA-Z0-9.-]+ )    # Package name
        >x
      ) do |match|
        backslashes = $1 || ''
        package = get_package($2)
        if package.nil?
          raise RepositoryError.new("Package not found: #{$1}")
        end
        backslashes + package.directory
      end
    end

    # The value is expected to have had any @ substitution already done, but
    # collapsing of escapes not done yet.
    def check_for_bad_escape(substituted, original)
      if substituted =~ %r<
        (?: ^ | [^\\])  # Start of line or non backslash
        (?: \\{2})*     # Even number of backslashes (including zero)
        ( \\ [^\\@] )   # A bad escape
      >x
        raise RepositoryError.new(
          %Q<Unknown escape "#{$1}" in "#{original}">
        )
      end

      return
    end

    def translate_retrieve_variables(base_package, name)
      return \
        @retrieve_vars[name].gsub(/ \[package\] /x, base_package.name)
    end
  end
end
