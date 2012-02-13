module Fig; end;

module Fig::EnvironmentVariables
  def initialize(variables_override = nil)
    @original_variables = variables_override || get_system_environment_variables
    @variables = @original_variables
  end

  def empty?
    return @variables.empty?
  end

  def keys
    return @variables.keys
  end

  def set_system_environment_variables(variables = @variables)
    variables.each { |key, value| ENV[key] = value }

    return
  end

  def reset_system_environment_variables
    set_system_environment_variables(@original_variables)

    return
  end

  private

  def get_system_environment_variables
    vars = {}
    ENV.each { |key,value| vars[key]=value }

    return vars
  end
end
