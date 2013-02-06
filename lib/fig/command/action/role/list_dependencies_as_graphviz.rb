require 'set'

require 'fig/command/action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesAsGraphviz
  def execute()
    @subgraphs = {}

    puts 'digraph {'
    puts '    node [shape = box];'
    walk_dependency_tree(
      @execution_context.base_package,
      base_display_config_names(),
      include_emit,
      &package_gather
    )
    emit_subgraphs
    puts '}'

    return Fig::Command::Action::EXIT_SUCCESS
  end

  private

  def include_emit
    visited = Set.new

    return lambda do
      |including_package, including_config, included_package, included_config|

      including_name = node_name(including_package, including_config)
      included_name = node_name(included_package, included_config)
      edge = %Q/    "#{including_name}" -> "#{included_name}";/

      if ! visited.include? edge
        visited << edge
        puts edge
      end
    end
  end

  def package_gather
    visited = Set.new

    return lambda do
      |package, config_name, depth|

      name = node_name package, config_name

      if ! visited.include? name
        visited << name

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

        package_name = node_name package, nil
        @subgraphs[package_name] ||= []
        @subgraphs[package_name] <<
          %Q<"#{name}" [label = "#{name}"#{style}#{color}];>
      end
    end
  end

  def emit_subgraphs()
    @subgraphs.each do
      |package_name, nodes|

      cluster = nodes.size > 1 ? 'cluster ' : ''
      puts %Q<    subgraph "#{cluster}#{package_name}" {>
      nodes.each { |node| puts %Q<        #{node}> }
      puts %q<    }>
    end

    return
  end

  def node_name(package, config_name)
    return package.to_s_with_config(config_name)
  end
end
