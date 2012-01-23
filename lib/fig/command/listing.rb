require 'set'

require 'fig/package'
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
      display_dependencies_in_tree(@package, derive_base_display_config_names())
    else
      display_dependencies_flat()
    end

    return
  end

  def display_variables()
    if @options.list_tree?
      raise Fig::UserInputError.new('--list-variables --list-tree not yet implemented.')
    else
      display_variables_flat()
    end

    return
  end

  def display_dependencies_in_tree(package, config_names, indent = 0)
    config_names.each do
      |config_name|

      print ' ' * (indent * 4)
      puts package.to_s_with_config(config_name)

      package.package_dependencies(config_name).each do
        |descriptor|

        display_dependencies_in_tree(
          @repository.get_package(descriptor.name, descriptor.version),
          [descriptor.config],
          indent + 1
        )
      end
    end

    return
  end

  def display_dependencies_flat()
    base_config_names = derive_base_display_config_names()
    packages = gather_package_depencency_configurations(base_config_names)

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

  def gather_package_depencency_configurations(starting_config_names)
    packages = {}

    if ! @package.package_name.nil?
      packages[@package] = starting_config_names.to_set
    end

    starting_config_names.each do
      |config_name|

      @package[config_name].walk_statements_following_package_dependencies(
        @repository, @package
      ) do
        |package, statement|

        if (
              ! package.package_name.nil?               \
          &&  statement.is_a?(Fig::Statement::Configuration)
        )
          packages[package] ||= Set.new
          packages[package] << statement.name
        end
      end
    end

    if ! @options.list_all_configs? && @descriptor
      packages.reject! do
        |package, config_names|
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

  def display_variables_flat()
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
