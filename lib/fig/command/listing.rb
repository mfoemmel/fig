require 'set'

require 'fig/backtrace'
require 'fig/package'
require 'fig/packagedescriptor'
require 'fig/userinputerror'

module Fig; end
class Fig::Command; end

# Parts of the Command class related to handling of --list-* options, simply to
# keep the size of command.rb down.
module Fig::Command::Listing
  private

  def display_local_package_list()
    check_disallowed_package_descriptor('--list-local')
    @repository.list_packages.sort.each do |item|
      puts item
    end
  end

  def display_remote_package_list()
    check_disallowed_package_descriptor('--list-remote')
    @repository.list_remote_packages.sort.each do |item|
      puts item
    end
  end

  def display_configs_in_local_packages_list()
    @package.configs.each do |config|
      puts config.name
    end

    return
  end

  def handle_pre_parse_list_options()
    case @options.listing()
    when :local_packages
      display_local_package_list()
    when :remote_packages
      display_remote_package_list()
    else
      return false
    end

    return true
  end

  def display_dependencies()
    if @options.list_tree?
      display_dependencies_in_tree()
    else
      display_dependencies_flat()
    end

    return
  end

  def display_variables()
    if @options.list_tree?
      display_variables_in_tree()
    elsif @options.list_all_configs?
      display_variables_flat_from_repository()
    else
      display_variables_flat_from_environment()
    end

    return
  end

  def display_dependencies_in_tree()
    walk_dependency_tree(@package, derive_base_display_config_names(), nil, 0) do
      |package, config_name, depth|

      print ' ' * (depth * 4)
      puts package.to_s_with_config(config_name)
    end

    return
  end

  def walk_dependency_tree(base_package, config_names, backtrace, depth, &block)
    config_names.each do
      |config_name|

      yield base_package, config_name, depth

      new_backtrace = Fig::Backtrace.new(
        backtrace,
        Fig::PackageDescriptor.new(
          base_package.package_name(),
          base_package.version_name(),
          config_name
        )
      )

      base_package.package_dependencies(config_name, new_backtrace).each do
        |descriptor|

        package = nil
        if descriptor.name
          package =
            @repository.get_package(descriptor, false, :allow_any_version)
        else
          package = base_package
        end

        walk_dependency_tree(
          package, [descriptor.config], new_backtrace, depth + 1, &block
        )
      end
    end

    return
  end

  def display_dependencies_flat()
    packages = gather_package_dependency_configurations()

    if packages.empty? and $stdout.tty?
      puts '<no dependencies>'
    else
      packages.keys.sort.each do
        |package|

        if @options.list_all_configs?
          packages[package].sort.each do
            |config_name|

            puts package.to_s_with_config(config_name)
          end
        else
          puts package
        end
      end
    end

    return
  end

  def derive_base_display_config_names()
    if @options.list_all_configs?
      return @package.config_names
    end

    return [
      @descriptor && @descriptor.config || Fig::Package::DEFAULT_CONFIG
    ]
  end

  def gather_package_dependency_configurations()
    packages = {}
    starting_config_names = derive_base_display_config_names()

    if ! @package.package_name.nil?
      packages[@package] = starting_config_names.to_set
    end

    walk_dependency_tree(@package, starting_config_names, nil, 0) do
      |package, config_name, depth|

      if (
            ! package.package_name.nil?           \
        &&  ! (
                  ! @options.list_all_configs?    \
              &&  @descriptor                     \
              &&  package.package_name == @descriptor.name
            )
      )
        packages[package] ||= Set.new
        packages[package] << config_name
      end
    end

    if ! @options.list_all_configs? && @descriptor
      packages.reject! do |package, config_names|
        package.package_name == @descriptor.name
      end
    end

    return packages
  end

  def handle_post_parse_list_options()
    case @options.listing()
    when :configs
      display_configs_in_local_packages_list()
    when :dependencies
      display_dependencies()
    when :variables
      display_variables()
    else
      raise %Q<Bug in code! Found unknown :listing option value "#{options.listing()}">
    end

    return
  end

  VariableTreePackageConfig =
    Struct.new(
      :package, :config_name, :variable_statements, :child_configs, :parent
    )

  def display_variables_in_tree()
    # We can't just display as we walk the dependency tree because we need to
    # know in advance how many configurations we're going display under
    # another.
    tree = build_variable_tree()

    tree.child_configs().each do
      |child|

      display_variable_tree_level(child, '', '')
    end

    return
  end

  def build_variable_tree()
    tree = VariableTreePackageConfig.new(nil, nil, nil, [], nil)
    prior_depth = 0
    prior_node = nil
    current_parent = tree

    walk_dependency_tree(@package, derive_base_display_config_names(), nil, 0) do
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

  def display_variables_flat_from_repository()
    variable_names = Set.new()

    walk_dependency_tree(@package, derive_base_display_config_names(), nil, 0) do
      |package, config_name, depth|

      package[config_name].walk_statements() do |statement|
        case statement
          when Fig::Statement::Path
            variable_names << statement.name()
          when Fig::Statement::Set
            variable_names << statement.name()
        end
      end
    end

    variable_names.sort.each { |name| puts name }

    return
  end

  def display_variables_flat_from_environment()
    register_package_with_environment()

    variables = @environment.variables()

    if variables.empty? and $stdout.tty?
      puts '<no variables>'
    else
      variables.keys.sort.each do |variable|
        puts variable + "=" + variables[variable]
      end
    end

    return
  end
end
