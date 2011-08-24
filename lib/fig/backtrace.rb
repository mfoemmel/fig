class Backtrace
  def initialize(parent, package_name, version_name, config_name)
    @parent = parent
    @package_name = package_name
    @version_name = version_name
    @config_name = config_name || "default"
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

  def dump(out)
    stack = []
    collect(stack)
    i=0
    for elem in stack
      indent=""
      i.times { indent += " " }
      out.puts indent+elem
    end
   end
end
