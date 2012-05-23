require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Publish
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--publish>
  end

  def descriptor_action()
    return :required
  end

  def need_base_package?()
    return true
  end

  def need_base_config?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_base_config?()
    return true
  end
end
