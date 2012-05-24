require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/command/action/role/publish'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Publish
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction
  include Fig::Command::Action::Role::Publish

  def options()
    return %w<--publish>
  end
end
