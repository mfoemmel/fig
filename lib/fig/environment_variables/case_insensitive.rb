# coding: utf-8

require 'fig/environment_variables'

module Fig; end;
module Fig::EnvironmentVariables; end

# Manager of a set of environment variables where the variable names are
# case-insensitive, e.g. on MS Windows.
class Fig::EnvironmentVariables::CaseInsensitive
  include Fig::EnvironmentVariables

  def [](key)
    return @variables[key_to_store_under(key)]
  end

  def []=(key, new_value)
    @variables[key_to_store_under(key)] = new_value

    return
  end

  def prepend_variable(key, new_value)
    existing_key = key_to_store_under(key)

    if existing_key
      assign_value_to_existing_key(existing_key, new_value)
    else
      @variables[key] = new_value
    end

    return
  end

  private

  def assign_value_to_existing_key(existing_key, new_value)
    current_value = @variables[existing_key]
    if current_value
      @variables[existing_key] = new_value + File::PATH_SEPARATOR + current_value
    else
      @variables[existing_key] = new_value
    end

    return
  end

  def key_to_store_under(key)
    return @variables.keys.detect(lambda {key}) {|stored| stored.downcase == key.downcase}
  end
end
