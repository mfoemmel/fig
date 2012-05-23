module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::Default
  def options
    return %w<--list-dependencies>
  end

  def descriptor_action()
    return nil
  end

  def need_base_package?()
    return true
  end

  def need_base_config?()
    return true
  end

  def register_base_package?()
    return false
  end

  def apply_base_config?()
    return false
  end
end
