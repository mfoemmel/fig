module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::HasSubAction
  attr_accessor :sub_action

  def sub_action?
    true
  end
end
