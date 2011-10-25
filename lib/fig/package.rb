module Fig
  class Package
    attr_reader :package_name, :version_name, :directory, :statements
    attr_accessor :backtrace

    def initialize(package_name, version_name, directory, statements)
      @package_name = package_name
      @version_name = version_name
      @directory = directory
      @statements = statements
      @backtrace = nil
    end

    def [](config_name)
      @statements.each do |stmt|
        return stmt if stmt.is_a?(Configuration) && stmt.name == config_name
      end
      $stderr.puts "Configuration not found: #{@package_name}/#{@version_name}:#{config_name}"
      exit 10
    end

    def configs
      @statements.select { |statement| statement.is_a?(Configuration) }
    end

    def retrieves
      retrieves = {}
      statements.each { |statement| retrieves[statement.var] = statement.path if statement.is_a?(Retrieve) }
      retrieves
    end

    def archive_urls
      @statements.select{|s| s.is_a?(Archive)}.map{|s|s.url}
    end

    def resource_urls
      @statements.select{|s| s.is_a?(Resource)}.map{|s|s.url}
    end

    def unparse
      @statements.map { |statement| statement.unparse('') }.join("\n")
    end

    def ==(other)
      @package_name == other.package_name && @version_name == other.version_name && @statements.to_yaml == other.statements.to_yaml
    end

    def to_s
      @package_name + '/' + @version_name
    end
  end

  class Archive
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def unparse(indent)
      %Q<#{indent}archive "#{url}">
    end
  end

  class Resource
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def unparse(indent)
      "#{indent}resource #{url}"
    end
  end

  class Retrieve
    attr_reader :var, :path

    def initialize(var, path)
      @var = var
      @path = path
    end

    def unparse(indent)
      "#{indent}retrieve #{var}->#{path}"
    end
  end

  class Publish
    attr_reader :local_name, :remote_name

    def initialize(local_name, remote_name)
      @local_name = local_name
      @remote_name = remote_name
    end

    def unparse(indent)
      "#{indent}publish #{@local_name}->#{@remote_name}"
    end
  end

  class Install
    def initialize(statements)
      @statements = statements
    end

    def unparse(indent)
      prefix = "\n#{indent}install"
      body = @statements.map { |statement| statement.unparse(indent+'  ') }.join("\n")
      suffix = "#{indent}end"
      return [prefix, body, suffix].join("\n")
    end
  end

  class Configuration
    attr_reader :name, :statements

    def initialize(name, statements)
      @name = name
      @statements = statements
    end

    def with_name(name)
      Configuration.new(name, statements)
    end

    def commands
      result = statements.select { |statement| statement.is_a?(Command) }
      result
    end

    def unparse(indent)
      unparse_statements(indent, "config #{@name}", @statements, 'end')
    end
  end

  class Path
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def unparse(indent)
      "#{indent}append #{name}=#{value}"
    end
  end

  class Set
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def unparse(indent)
      "#{indent}set #{name}=#{value}"
    end
  end

  class Include
    attr_reader :package_name, :config_name, :version_name, :overrides

    def initialize(package_name, config_name, version_name, overrides)
      @package_name = package_name
      @config_name = config_name
      @version_name = version_name
      @overrides = overrides
    end

    def unparse(indent)
      descriptor = ''
      descriptor += @package_name if @package_name
      descriptor += "/#{@version_name}" if @version_name
      descriptor += ":#{@config_name}" if @config_name
      @overrides.each do |override|
        descriptor += override.unparse
      end
      return "#{indent}include #{descriptor}"
    end
  end

  class Override
    attr_reader :package_name, :version_name

    def initialize(package_name, version_name)
      @package_name = package_name
      @version_name = version_name
    end

    def unparse()
      return ' override ' + @package_name + '/' + @version_name
    end
  end

  class Command
    attr_reader :command

    def initialize(command)
      @command = command
    end

    def unparse(indent)
      %Q<#{indent}command "#{@command}">
    end
  end

end

def unparse_statements(indent, prefix, statements, suffix)
  body = @statements.map { |statement| statement.unparse(indent+'  ') }.join("\n")
  return ["\n#{indent}#{prefix}", body, "#{indent}#{suffix}"].join("\n")
end

