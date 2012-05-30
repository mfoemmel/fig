require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListConfigs
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--list-configs>
  end

  def descriptor_requirement()
    return nil
  end

  def need_base_package?()
    return true
  end

  def register_base_package?()
    return nil # don't care
  end

  def apply_config?()
    return nil # don't care
  end

  def execute()
    @execution_context.base_package.configs.each do |config|
      puts config.name
    end

    return EXIT_SUCCESS
  end
end
