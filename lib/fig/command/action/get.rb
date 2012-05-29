require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Get
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--get>
  end

  def descriptor_requirement()
    return nil
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

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return true
  end

  def configure(options)
    @variable = options.variable_to_get
  end

  def execute()
    # Ruby v1.8 emits "nil" for nil, whereas ruby v1.9 emits the empty
    # string, so, for consistency, we need to ensure that we always emit the
    # empty string.
    puts @execution_context.environment[@variable] || ''

    return 0
  end
end
