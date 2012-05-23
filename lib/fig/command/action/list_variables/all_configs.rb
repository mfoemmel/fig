module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::AllConfigs
  def options
    return %w<--list-variables --list-all-configs>
  end
end
