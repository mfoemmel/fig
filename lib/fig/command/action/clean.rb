require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Clean
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--clean>
  end
end