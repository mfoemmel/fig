require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListRemote
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  # TODO: delete this
  def implemented?
    return true
  end

  def options()
    return %w<--list-remote>
  end

  def descriptor_requirement()
    return :warn
  end

  def need_base_package?()
    return false
  end

  def execute(repository)
    repository.list_remote_packages.sort.each {|item| puts item}

    return 0
  end
end
