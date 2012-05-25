module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListAllConfigs
  def list_all_configs?
    return true
  end

  def base_display_config_names()
    return @execution_context.base_package.config_names
  end
end
