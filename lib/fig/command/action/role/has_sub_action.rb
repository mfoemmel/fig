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

  # TODO: Delete this.
  def implemented?
    check_sub_action_presence()
    return sub_action.implemented?
  end

  def descriptor_requirement()
    check_sub_action_presence()
    return sub_action.descriptor_requirement()
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
    return sub_action.register_base_package?
  end

  def apply_config?()
    check_sub_action_presence()
    return sub_action.apply_config?
  end

  def apply_base_config?()
    check_sub_action_presence()
    return sub_action.apply_base_config?
  end

  def configure(options)
    check_sub_action_presence()
    return sub_action.configure(options)
  end

  def execution_context=(context)
    check_sub_action_presence()
    sub_action.execution_context = context
  end

  def execute()
    check_sub_action_presence()
    return sub_action.execute()
  end
end
