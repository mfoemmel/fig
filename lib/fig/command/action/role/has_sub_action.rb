module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::HasSubAction
  attr_accessor :sub_action

  def sub_action?()
    true
  end

  def check_sub_action_presence()
    return if sub_action

    raise 'Bug in code. Sub-action missing.'
  end

  def descriptor_action()
    check_sub_action_presence()
    return sub_action.descriptor_action()
  end

  def need_base_package?()
    check_sub_action_presence()
    return sub_action.need_base_package?
  end

  def need_base_config?()
    check_sub_action_presence()
    return sub_action.need_base_package?
  end

  def register_base_package?()
    check_sub_action_presence()
    return sub_action.apply_base_package?
  end

  def apply_base_config?()
    check_sub_action_presence()
    return sub_action.apply_base_package?
  end
end
