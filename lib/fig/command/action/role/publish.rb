module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::Publish
  def descriptor_requirement()
    return :required
  end

  def allow_both_descriptor_and_file?()
    # Actually, publishing requires a descriptor and another source of the base
    # package.
    return true
  end

  def need_base_package?()
    return true
  end

  def base_package_can_come_from_descriptor?()
    return false
  end

  def need_base_config?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return false
  end
end
