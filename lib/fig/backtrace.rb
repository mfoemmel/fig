module Fig; end

# Contains traces of file inclusions so that the user can track down which file
# an error occurred in.
class Fig::Backtrace
  attr_reader :overrides

  def initialize(parent, descriptor)
    @parent     = parent
    @descriptor = descriptor
    @overrides  = {}
  end

  def add_override(package_name, version)
    # Don't replace an existing override on the stack
    return if get_override(package_name)

    @overrides[package_name] = version
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
    i=0
    for descriptor in stack
      indent=''
      i.times { indent += '  ' }
      out.puts indent + descriptor.to_string(:use_default_config)
      i += 1
    end
  end

  private

  def collect(stack)
    if @parent
      @parent.collect(stack)
    end

    stack << @descriptor
  end
end
