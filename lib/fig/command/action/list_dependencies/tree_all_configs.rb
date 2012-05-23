module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::TreeAllConfigs
  def options
    return %w<--list-dependencies --list-tree --list-all-configs>
  end
end
