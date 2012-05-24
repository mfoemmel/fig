require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListLocal
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  # TODO: delete this
  def implemented?
    return true
  end

  def options()
    return %w<--list-local>
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

  def execute(repository)
    repository.list_packages.sort.each {|item| puts item}

    return 0
  end
end
