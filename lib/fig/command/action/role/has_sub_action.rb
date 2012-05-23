module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::HasSubAction
  def sub_action
    return @sub_action
  end

  def sub_action?
    true
  end
end
