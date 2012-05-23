require 'fig/repository_error'

module Fig; end

# Stack of applied "include" statements.
#
# Keeps track of overrides and can produce package definition stack traces.
#
# Pushing and popping actually happens via instances being held/let go by
# recursive method calls on Environment.
class Fig::IncludeBacktrace
  attr_reader :overrides

  def initialize(parent, descriptor)
    @parent     = parent
    @descriptor = descriptor
    @overrides  = {}
  end

  def add_override(statement)
    package_name = statement.package_name
    # Don't replace an existing override on the stack
    return if @parent && @parent.get_override(package_name)

    new_version = statement.version
    existing_version = @overrides[package_name]
    if existing_version && existing_version != new_version
      stacktrace = dump_to_string()
      raise Fig::RepositoryError.new(
        "Override #{package_name} version conflict (#{existing_version} vs #{new_version})#{statement.position_string}." + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
      )
    end

    @overrides[package_name] = new_version
  end

  # Returns a version.
  def get_override(package_name, default_version = nil)
    version = @overrides[package_name]
    return version if version

    return @parent.get_override(package_name, default_version) if @parent
    return default_version
  end

  # Prints a stack trace to the IO object.
  def dump(out)
    stack = []
    collect(stack)
    i = 0
    for descriptor in stack
      indent=''
      i.times { indent += '  ' }
      out.puts indent + descriptor.to_string(:use_default_config)
      i += 1
    end
  end

  protected

  def dump_to_string()
    string_handle = StringIO.new
    dump(string_handle)
    return string_handle.string
  end

  def collect(stack)
    if @parent
      @parent.collect(stack)
    end

    stack << @descriptor
  end
end
