require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListRemote
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--list-remote>
  end

  def descriptor_requirement()
    return :warn
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
