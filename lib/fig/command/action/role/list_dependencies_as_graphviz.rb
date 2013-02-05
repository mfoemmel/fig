require 'set'

require 'fig/command/action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesAsGraphviz
  def execute()
    puts 'digraph {'
    walk_dependency_tree(
      @execution_context.base_package,
      base_display_config_names(),
      include_emit,
      &package_emit
    )
    puts '}'

    return Fig::Command::Action::EXIT_SUCCESS
  end

  private

  def include_emit
    visited = Set.new

    return lambda do
      |including_package, including_config, included_package, included_config|

      including_name = including_package.to_s_with_config(including_config)
      included_name = included_package.to_s_with_config(included_config)
      edge = %Q/    "#{including_name}" -> "#{included_name}";/

      if ! visited.include? edge
        visited << edge
        puts edge
      end
    end
  end

  def package_emit
    visited = Set.new

    return lambda do
      |package, config_name, depth|

      name = package.to_s_with_config(config_name)

      if ! visited.include? name
        visited << name

        style = ''
        if (
          package == @execution_context.base_package      &&
          base_display_config_names.include?(config_name)
        )
          style = ' style = bold'
        end

        puts %Q<    "#{name}" [label = "#{name}"#{style}];>
      end
    end
  end
end
