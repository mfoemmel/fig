# coding: utf-8

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesFromDataStructure
  private

  def node_content(package, config_name)
    return new_package_config_hash package, config_name
  end
end
