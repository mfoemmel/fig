require 'stringio'

require 'fig/backtrace'
require 'fig/logging'
require 'fig/package/command'
require 'fig/package/include'
require 'fig/package/path'
require 'fig/package/set'
require 'fig/repositoryerror'

module Fig
  # This class manages the program's state, including the value of all
  # environment variables, and which packages have already been applied.
  class Environment
    DEFAULT_VERSION_NAME = 'current'

    def initialize(os, repository, variables, retriever)
      @os = os
      @repository = repository
      @variables = variables
      @retrieve_vars = {}
      @packages = {}
      @applied_configs = {}
      @retriever = retriever
    end

    # Returns the value of an envirionment variable
    def [](name)
      @variables[name]
    end

    # Indicates that the values from a particular envrionment variable path
    def add_retrieve(name, path)
      @retrieve_vars[name] = path
    end

    def register_package(package)
      name = package.package_name
      if @packages[name]
        Logging.fatal %Q<There is already a package with the name "#{name}".>
        raise RepositoryError.new
      end
      @packages[name] = package
    end

    def apply_config(package, config_name, backtrace)
      if (@applied_configs[package.package_name] ||= []).member?(config_name)
        return
      end
      new_backtrace = backtrace

      config = package[config_name]
      config.statements.each { |stmt| apply_config_statement(package, stmt, new_backtrace) }
      @applied_configs[package.package_name] << config_name
    end

    def execute_shell(command)
      with_environment do
        yield command.map{|arg| expand_command_line_argument(arg)}
      end
    end

    def execute_config(base_package, package_name, config_name, version_name, args)
      package = lookup_package(
        package_name || base_package.package_name,
        version_name,
        Backtrace.new(nil, package_name, version_name, config_name)
      )
      result = nil
      commands = package[config_name || 'default'].commands
      with_environment do
        # TODO nil check
        commands.each do |command|
          argument =
            expand_command_line_argument(
              "#{command.command} #{args.join(' ')}"
            )

          result = yield expand_path(argument, package).split(' ')
        end
      end
      result
    end

    def apply_config_statement(base_package, statement, backtrace)
      case statement
      when Package::Path
        append_variable(base_package, statement.name, statement.value)
      when Package::Set
        set_variable(base_package, statement.name, statement.value)
      when Package::Include
        include_config(base_package, statement.package_name, statement.config_name, statement.version_name, statement.overrides, backtrace)
      when Package::Command
        # ignore
      else
        fail "Unexpected statement: #{statement}"
      end
    end

    def include_config(base_package, package_name, config_name, version_name, overrides, backtrace)
      # Check to see if this include has been overridden.
      if backtrace
        override = backtrace.get_override(package_name || base_package.package_name)
        if override
          version_name = override
        end
      end
      new_backtrace = Backtrace.new(backtrace, package_name, version_name, config_name)
      overrides.each do |override|
        new_backtrace.add_override(override.package_name, override.version_name)
      end
      package = lookup_package(package_name || base_package.package_name, version_name, new_backtrace)
      apply_config(package, config_name || 'default', new_backtrace)
    end

    private

    def set_variable(base_package, name, value)
      @variables[name] = expand_and_retrieve_variable_value(base_package, name, value)
    end

    def append_variable(base_package, name, value)
      value = expand_and_retrieve_variable_value(base_package, name, value)
      # TODO: converting all environment variables to upcase is not a robust
      #       comparison. It also assumes all env vars will be in upcase
      #       in package.fig
      prev = nil
      @variables.each do |key, val|
        if key.upcase == name.upcase
          name = key
          prev = val
        end
      end
      if prev
        @variables[name] = value + File::PATH_SEPARATOR + prev
      else
        @variables[name] = value
      end
    end

    def with_environment
      old_env = {}
      begin
        @variables.each { |key,value| old_env[key] = ENV[key]; ENV[key] = value }
        yield
      ensure
        old_env.each { |key,value| ENV[key] = value }
      end
    end

    def lookup_package(package_name, version_name, backtrace)
      package = @packages[package_name]
      if package.nil?
        package = @repository.load_package(package_name, version_name || DEFAULT_VERSION_NAME)
        package.backtrace = backtrace
        @packages[package_name] = package
      elsif version_name && version_name != package.version_name
        string_handle = StringIO.new
        backtrace.dump(string_handle) if backtrace
        package.backtrace.dump(string_handle) if package.backtrace
        stacktrace = string_handle.string
        Logging.fatal                           \
            "Version mismatch: #{package_name}" \
          + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
        raise RepositoryError.new
      end
      package
    end

    # Replace @ symbol with the package's directory, "[package]" with the
    # package name.
    def expand_and_retrieve_variable_value(base_package, name, value)
      return value unless base_package && base_package.package_name

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
        @retriever.with_package_config(
          base_package.package_name, base_package.version_name
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
        package = @packages[$2]
        if package.nil?
          raise RepositoryError.new "Package not found: #{$1}"
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
    end

    def translate_retrieve_variables(base_package, name)
      return \
        @retrieve_vars[name].gsub(
          / \[package\] /x,
          base_package.package_name
        )
    end
  end
end
