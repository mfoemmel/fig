require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/archive'
require 'fig/package/configuration'
require 'fig/package/resource'
require 'fig/package/retrieve'

module Fig; end

# The parsed representation of a configuration file.  Contains the statement
# objects.
class Fig::Package
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
    message = "Configuration not found: #{@package_name}/#{@version_name}:#{config_name}"
    raise Fig::PackageError.new(message)
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

  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end
  end

  def unparse
    @statements.map { |statement| statement.unparse('') }.join("\n")
  end

  def ==(other)
    return false if other.nil?
    @package_name == other.package_name && @version_name == other.version_name && @statements.to_yaml == other.statements.to_yaml
  end

  def to_s
    package_name = @package_name || 'uninitialized'
    version_name = @version_name || 'uninitialized'
    package_name + '/' + version_name
  end
end

def unparse_statements(indent, prefix, statements, suffix)
  body = @statements.map { |statement| statement.unparse(indent+'  ') }.join("\n")
  return ["\n#{indent}#{prefix}", body, "#{indent}#{suffix}"].join("\n")
end
