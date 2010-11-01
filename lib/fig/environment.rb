module Fig

  # This class manages the program's state, including the value of all environment 
  # variables, and which packages have already been applied
  class Environment
    DEFAULT_VERSION_NAME = "current"

    def initialize(os, repository, variables)
      @os = os
      @repository = repository
      @variables = variables
      @retrieve_vars = {}
      @packages = {}
    end

    # Returns the value of an envirionment variable
    def [](name)
      @variables[name]
    end

    # Indicates that the values from a particular envrionment variable path should
    # be copied to a local directory 
    def add_retrieve(name, path)
      @retrieve_vars[name] = path
    end

    def register_package(package)
      name = package.package_name
      raise "Package already exists with name: #{name}" if @packages[name]
      @packages[name] = package
    end

    def apply_config(package, config_name)
      config = package[config_name]
      config.statements.each { |stmt| apply_config_statement(package, stmt) }
    end

    def execute_shell(command)
      with_environment do
        yield command.map{|arg| expand_arg(arg)}
      end
    end

    def execute_config(base_package, package_name, config_name, version_name, args)
      package = lookup_package(package_name || base_package.package_name, version_name)
      result = nil
      commands = package[config_name || "default"].commands
      with_environment do
        # todo nil check
        commands.each do |command|
          result = yield expand_arg("#{command.command} #{args.join(' ')}").gsub("@",package.directory).split(" ")
        end
      end
      result
    end

    def apply_config_statement(base_package, statement)
      case statement
      when Path
        append_variable(base_package, statement.name, statement.value)
      when Set
        set_variable(base_package, statement.name, statement.value)
      when Include
        include_config(base_package, statement.package_name, statement.config_name, statement.version_name)
      when Command
        # ignore
      else
        fail "Unexpected statement: #{statement}"
      end
    end

    def include_config(base_package, package_name, config_name, version_name)
      package = lookup_package(package_name || base_package.package_name, version_name)
      apply_config(package, config_name || "default")
    end

    def direct_retrieve(package_name, source_path, target_path)
      package = lookup_package(package_name, nil)
      FileUtils.mkdir_p(target_path)
      FileUtils.cp_r(File.join(package.directory, source_path, '.'), target_path)
    end

    private 

    def set_variable(base_package, name, value)
      @variables[name] = expand_value(base_package, name, value)
    end

    def append_variable(base_package, name, value)
      value = expand_value(base_package, name, value)
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

    def lookup_package(package_name, version_name)
      package = @packages[package_name]
      if package.nil?
        package = @repository.load_package(package_name, version_name || DEFAULT_VERSION_NAME)
        @packages[package_name] = package
      elsif version_name && version_name != package.version_name
        raise "Version mismatch: #{package_name}" 
      end
      package
    end

    # Replace @ symbol with the package's directory
    def expand_value(base_package, name, value)
      return value unless base_package && base_package.package_name
      file = value.gsub(/\@/, base_package.directory)
      if @retrieve_vars.member?(name)
        # A '//' in the source file's path tells us to preserve path information
        # after the '//' when doing a retrieve.
        if file.split('//').size > 1
          preserved_path = file.split('//').last
          target = File.join(@retrieve_vars[name].gsub(/\[package\]/, base_package.package_name), preserved_path)
        else
          target = File.join(@retrieve_vars[name].gsub(/\[package\]/, base_package.package_name), File.basename(file))
        end
        unless @os.exist?(target) && @os.mtime(target) >= @os.mtime(file)
          @os.log_info("retrieving #{target}")
          @os.copy(file, target)
        end
        file = target
      end
      file
    end

    def expand_arg(arg)
      arg.gsub(/\@([a-zA-Z0-9\-\.]+)/) do |match|
        package = @packages[$1]
        raise "Package not found: #{$1}" if package.nil?
        package.directory
      end
    end
  end
end
