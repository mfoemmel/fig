require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListLocal
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--list-local>
  end

  def descriptor_requirement()
    return :warn
  end

  def need_base_package?()
    return false
  end

  def execute()
    @execution_context.repository.list_packages.sort.each {|item| puts item}

    return EXIT_SUCCESS
  end
end
