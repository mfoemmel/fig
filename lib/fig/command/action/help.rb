require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Help
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--help>
  end

  def descriptor_action()
    return :ignore
  end

  def need_base_package?()
    return false
  end

  def need_base_config?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_base_config?()
    return false
  end
end
