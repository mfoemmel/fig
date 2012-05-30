require 'fig/command/action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::Default
  include Fig::Command::Action

  def options()
    return %w<--list-variables>
  end

  def descriptor_requirement()
    return nil
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return true
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return true
  end

  def execute()
    variables = @execution_context.environment.variables()

    if variables.empty? and $stdout.tty?
      puts '<no variables>'
    else
      variables.keys.sort.each do |variable|
        puts variable + "=" + variables[variable]
      end
    end

    return EXIT_SUCCESS
  end
end
