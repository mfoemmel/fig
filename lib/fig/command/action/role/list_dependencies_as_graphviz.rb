module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesAsGraphviz
  private

  def node_content(package, config_name)
    name = node_name package, config_name

    style = ''
    color = ''
    if package == @execution_context.base_package
      if base_display_config_names.include?(config_name)
        style = ' style = "rounded, bold"'
      end
      if config_name == @execution_context.base_config
        color = ' color = blue'
      end
    end

    return %Q<"#{name}" [label = "#{name}"#{style}#{color}];>
  end
end
