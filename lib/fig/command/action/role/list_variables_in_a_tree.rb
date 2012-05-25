require 'fig/statement/path'
require 'fig/statement/set'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListVariablesInATree
  # TODO: Delete this.
  def implemented?
    return true
  end

  def descriptor_requirement()
    return nil
  end

  def need_base_package?()
    return true
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return false
  end

  def execute()
    # We can't just display as we walk the dependency tree because we need to
    # know in advance how many configurations we're going display under
    # another.
    tree = build_variable_tree()

    tree.child_configs().each do
      |child|

      display_variable_tree_level(child, '', '')
    end

    return 0
  end

  private

  VariableTreePackageConfig =
    Struct.new(
      :package, :config_name, :variable_statements, :child_configs, :parent
    )

  def build_variable_tree()
    tree = VariableTreePackageConfig.new(nil, nil, nil, [], nil)
    prior_depth = 0
    prior_node = nil
    current_parent = tree

    walk_dependency_tree(
      @execution_context.base_package, base_display_config_names(), nil, 0
    ) do
      |package, config_name, depth|

      if depth < prior_depth
        (depth .. (prior_depth - 1)).each do
          current_parent = current_parent.parent
        end
      elsif depth == prior_depth + 1
        current_parent = prior_node
      elsif depth > prior_depth
        raise "Bug in code! Descended more than one level! (#{prior_depth} to #{depth}"
      end

      variable_statements = gather_variable_statements(package[config_name])
      node = VariableTreePackageConfig.new(
        package, config_name, variable_statements, [], current_parent
      )
      current_parent.child_configs() << node

      prior_depth = depth
      prior_node = node
    end

    return tree
  end

  def gather_variable_statements(config_statement)
    variable_statements = []
    config_statement.walk_statements() do |statement|
      case statement
        when Fig::Statement::Path
          variable_statements << statement
        when Fig::Statement::Set
          variable_statements << statement
      end
    end

    return variable_statements
  end

  def display_variable_tree_level(node, base_indent, package_indent)
    print package_indent
    puts node.package().to_s_with_config(node.config_name())

    display_variable_tree_level_variables(node, base_indent)

    child_configs = node.child_configs()
    child_count = child_configs.size()

    new_indent = base_indent + (child_count > 0 ? '|' : ' ') + ' ' * 3
    new_package_indent = base_indent + %q<'--->

    (0 .. (child_count - 2)).each do
      |child_index|

      display_variable_tree_level(
        child_configs[child_index], new_indent, new_package_indent
      )
    end

    if child_count > 0
      display_variable_tree_level(
        child_configs[-1], (base_indent + ' ' * 4), new_package_indent
      )
    end
  end

  def display_variable_tree_level_variables(node, base_indent)
    if node.child_configs().size() > 0
      variable_indent = base_indent + '|' + ' ' * 3
    else
      variable_indent = base_indent + ' ' * 4
    end

    variable_statements = node.variable_statements()

    name_width =
      (variable_statements.map { |statement| statement.name().length() }).max()

    variable_statements.each do
      |statement|

      print "#{variable_indent}"
      print "#{statement.name().ljust(name_width)}"
      print " = #{statement.value}"
      if statement.is_a?(Fig::Statement::Path)
        print ":$#{statement.name}"
      end
      print "\n"
    end

    return
  end
end
