require 'fig/command/action/role/has_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::ListVariables
  include Fig::Command::Action::Role::HasSubAction

  def options
    if sub_action
      return sub_action.options
    end

    return %w<--list-variables>
  end
end
