require 'fig/logging'
require 'fig/nosuchpackageconfigerror'
require 'fig/packagedescriptor'
require 'fig/statement/archive'
require 'fig/statement/configuration'
require 'fig/statement/resource'
require 'fig/statement/retrieve'

module Fig; end

# The parsed representation of a configuration file for a specific version.
# Contains the statement objects.
#
# Unique identifier for this object: name and version. A different version of
# the same package will be a separate instance of this class.
class Fig::Package
  include Comparable

  UNPUBLISHED     = '<unpublished>'
  DEFAULT_CONFIG  = 'default'

  attr_reader   :name, :version, :directory, :statements
  attr_accessor :backtrace

  def initialize(name, version, directory, statements)
    @name = name
    @version = version
    @directory = directory
    @statements = statements
    @applied_config_names = []
    @backtrace = nil
  end

  def [](config_name)
    @statements.each do |stmt|
      return stmt if stmt.is_a?(Fig::Statement::Configuration) && stmt.name == config_name
    end

    descriptor = Fig::PackageDescriptor.new(@name, @version, config_name)
    config_description = nil
    if @name.nil? and @version.nil?
      config_description = config_name
    else
      config_description = descriptor.to_string(:use_default_config)
    end

    message = %Q<There is no "#{config_description}" config.>

    raise Fig::NoSuchPackageConfigError.new(message, descriptor)
  end

  def <=>(other)
    compared = compare_components(name, other.name)
    return compared if compared != 0

    return compare_components(version, other.version)
  end

  def configs
    return @statements.select { |statement| statement.is_a?(Fig::Statement::Configuration) }
  end

  def config_names
    return configs.collect { |statement| statement.name }
  end

  def retrieves
    return @statements.select { |statement| statement.is_a?(Fig::Statement::Retrieve) }
  end

  def archive_urls
    return @statements.select{|s| s.is_a?(Fig::Statement::Archive)}.map{|s| s.url}
  end

  def resource_urls
    return @statements.select{|s| s.is_a?(Fig::Statement::Resource)}.map{|s|s.url}
  end

  def applied_config_names()
    return @applied_config_names.clone
  end

  def add_applied_config_name(name)
    @applied_config_names << name
  end

  def primary_config_name()
    return @applied_config_names.first
  end

  # Returns an array of PackageDescriptors
  def package_dependencies(config_name, backtrace)
    descriptors = []

    self[config_name || DEFAULT_CONFIG].walk_statements do
      |statement|

      if statement.is_a?(Fig::Statement::Include)
        descriptors << statement.resolved_dependency_descriptor(self, backtrace)
      end
    end

    return descriptors
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end

    return
  end

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(repository, &block)
    @statements.each do |statement|
      yield self, statement
      statement.walk_statements_following_package_dependencies(
        repository, self, nil, &block
      )
    end

    return
  end

  def unparse
    return @statements.map { |statement| statement.unparse('') }.join("\n")
  end

  def ==(other)
    return false if other.nil?

    return @name == other.name &&
           @version == other.version &&
           @statements.to_yaml == other.statements.to_yaml
  end

  def to_s
    name    = @name || '<empty>'
    version = @version || '<empty>'
    return Fig::PackageDescriptor.format(name, version, nil)
  end

  def to_s_with_config(config_name)
    string = nil

    if name.nil?
      string = UNPUBLISHED
    else
      string = to_s
    end

    if not config_name.nil? and config_name != DEFAULT_CONFIG
      string += ":#{config_name}"
    end

    return string
  end

  def to_s_with_primary_config()
    return to_s_with_config(primary_config_name)
  end

  private

  def compare_components(mine, others)
    if mine.nil?
      if others.nil?
        return 0
      end

      return 1
    end

    if others.nil?
      return -1
    end

    return mine <=> others
  end
end

# TODO: get this out of the global namespace
def unparse_statements(indent, prefix, statements, suffix)
  body = @statements.map { |statement| statement.unparse(indent+'  ') }.join("\n")

  return ["\n#{indent}#{prefix}", body, "#{indent}#{suffix}"].join("\n")
end
