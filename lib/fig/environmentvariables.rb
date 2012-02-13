require 'fig/operatingsystem'

module Fig
  # Manges the getting and setting of environment variables in such a way
  # that the calling class can be agnostic about the actual platform used.
  class EnvironmentVariables
    def initialize(using_windows, variables_override = nil)
      @original_variables = variables_override || get_system_environment_variables
      @variables = @original_variables
      @using_windows = using_windows
    end

    def [](key)
      if @using_windows
        return @variables[get_current_key(key)]
      end

      return @variables[key]
    end

    def []=(new_key, new_value)
      @variables[get_current_key(new_key)] = new_value

      return
    end

    def empty?
      return @variables.empty?
    end

    def keys
      return @variables.keys
    end

    def append_variable(new_key, new_value)
      current_value = nil
      current_key = get_current_key(new_key)

      if current_key
        assign_value_to_current_key(current_key, new_value)
      else
        @variables[new_key] = new_value
      end

      return
    end

    def set_system_environment_variables(variables = @variables)
      variables.each { |key,value| ENV[key] = value }

      return
    end

    def reset_system_environment_variables
      set_system_environment_variables(@original_variables)

      return
    end

    private

    def assign_value_to_current_key(current_key, new_value)
      current_value = @variables[current_key]
      if current_value
        @variables[current_key] = new_value + File::PATH_SEPARATOR + current_value
      else
        @variables[current_key] = new_value
      end

      return
    end

    def get_current_key(new_key)
      @variables.each do |key, value|
        if keys_match?(new_key, key)
          return key
        end
      end

      return new_key
    end

    def keys_match?(new_key, current_key)
      if @using_windows
        return new_key.upcase == current_key.upcase
      end

      return new_key == current_key
    end

    def get_system_environment_variables
      vars = {}
      ENV.each { |key,value| vars[key]=value }

      return vars
    end
  end
end
