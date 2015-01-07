# coding: utf-8

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListBaseConfig
  def list_all_configs?
    return false
  end

  def base_display_config_names()
    return [@execution_context.base_config]
  end
end
