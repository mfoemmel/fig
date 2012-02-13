require 'fig/environmentvariables'

module Fig; end;
module EnvironmentVariables; end


class Fig::EnvironmentVariables::CaseSensitive
  include Fig::EnvironmentVariables

  def [](key)
    return @variables[key]
  end

  def []=(new_key, new_value)
    @variables[new_key] = new_value

    return
  end

  def prepend_variable(key, new_value)
    if @variables.key?(key)
      @variables[key] = new_value + File::PATH_SEPARATOR + @variables[key]
    else
      @variables[key] = new_value
    end

    return
  end
end
