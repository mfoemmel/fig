module Fig; end;

# Abstract manager of a set of environment variables.
module Fig::EnvironmentVariables
  def initialize(variables_override = nil)
    @variables = variables_override || get_system_environment_variables
  end

  def empty?
    return @variables.empty?
  end

  def keys
    return @variables.keys
  end

  def with_environment
    original_environment = {}
    original_environment.merge!(ENV.to_hash)

    begin
      set_system_environment_variables(@variables)
      yield
    ensure
      ENV.clear
      set_system_environment_variables(original_environment)
    end

    return
  end

  private

  def get_system_environment_variables
    vars = {}
    ENV.each { |key,value| vars[key]=value }

    return vars
  end

  def set_system_environment_variables(variables)
    variables.each { |key, value| ENV[key] = value }
  end
end
