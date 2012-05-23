require 'fig/command/action/role/has_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListDependencies
  include Fig::Command::Action::Role::HasSubAction

  def options
    if sub_action
      return sub_action.options
    end

    return %w<--list-dependencies>
  end
end
