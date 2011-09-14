class Backtrace
  attr_reader :overrides

  def initialize(parent, package_name, version_name, config_name)
    @parent = parent
    @package_name = package_name
    @version_name = version_name
    @config_name = config_name || "default"
    @overrides = {}
  end

  def collect(stack)
    if @parent
      @parent.collect(stack)
    end
    elem = ""
    if @package_name
      elem = @package_name
    end
    if @version_name
      elem += "/" + @version_name
    end
    if @config_name
      elem += ":" + @config_name
    end
    stack << elem
  end

  def add_override(package_name, version_name)
    # Don't replace an existing override on the stack
    return if get_override(package_name)
    @overrides[package_name] = version_name
  end

  def get_override(package_name)
    return @overrides[package_name] || (@parent ? @parent.get_override(package_name) : nil)
  end

  def dump(out)
    stack = []
    collect(stack)
    i=0
    for elem in stack
      indent=""
      i.times { indent += "  " }
      out.puts indent+elem
      i += 1
    end
   end
end
