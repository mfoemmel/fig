module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::Update
  def descriptor_requirement()
    return nil
  end

  def allow_both_descriptor_and_file?()
    # We don't care, so we let the base action say what it wants.
    return true
  end

  def need_base_package?()
    return true
  end

  def need_base_config?()
    return true
  end

  def register_base_package?()
    return true
  end

  def apply_base_config?()
    return true
  end
end
