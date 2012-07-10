require 'fig/command/action'

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

  def modifies_repository?()
    return true
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return true
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return true
  end

  def retrieves_should_happen?()
    return true
  end

  def remote_operation_necessary?()
    return true
  end

  def execute()
    # Don't do anything.
    return Fig::Command::Action::EXIT_SUCCESS
  end
end
