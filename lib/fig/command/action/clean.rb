require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Clean
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  # TODO: delete this
  def implemented?
    return true
  end

  def options()
    return %w<--clean>
  end

  def descriptor_requirement()
    return :required
  end

  def need_base_package?()
    return false
  end

  def need_base_config?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return false
  end

  def apply_base_config?()
    return false
  end

  def configure(options)
    @descriptor = options.descriptor
  end

  def execute(repository)
    repository.clean(@descriptor)

    return 0
  end
end
