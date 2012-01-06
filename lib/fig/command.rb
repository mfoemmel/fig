require 'rubygems'
require 'net/ftp'
require 'log4r'

require 'fig/environment'
require 'fig/figrc'
require 'fig/logging'
require 'fig/options'
require 'fig/os'
require 'fig/package'
require 'fig/package/configuration'
require 'fig/package/publish'
require 'fig/parser'
require 'fig/repository'
require 'fig/retriever'
require 'fig/userinputerror'
require 'fig/windows'

module Fig; end

# Main program
class Fig::Command
  DEFAULT_FIG_FILE = 'package.fig'

  def raise_package_descriptor_required(operation_description)
    raise Fig::UserInputError.new(
      "Need to specify a package #{operation_description}."
    )
  end

  def raise_package_descriptor_not_allowed(operation_description)
    raise Fig::UserInputError.new(
      "Cannot specify a package for #{operation_description}."
    )
  end

  def read_in_package_config_file(config_file)
    if File.exist?(config_file)
      return File.read(config_file)
    else
      raise Fig::UserInputError.new(%Q<File not found: "#{config_file}".>)
    end
  end

  def initialize_shell_command(argv)
    shell_command = nil
    argv.each_with_index do |arg, i|
      if arg == '--'
        shell_command = argv[(i+1)..-1]
        argv.slice!(i..-1)
        break
      end
    end

    return shell_command
  end

  def remote_operation_necessary?(options)
    return options[:update]                       ||
           options[:publish]                      ||
           options[:update_if_missing]            ||
           options[:listing] == :remote_packages
  end

  def initialize_remote_url(options)
    if remote_operation_necessary?(options)
      if ENV['FIG_REMOTE_URL'].nil?
        raise Fig::UserInputError.new('Please define the FIG_REMOTE_URL environment variable.')
      end
      return ENV['FIG_REMOTE_URL']
    end

    return nil
  end

  def load_package_config_file_contents(options)
    package_config_file = options[:package_config_file]

    if package_config_file == :none
      return nil
    elsif package_config_file == '-'
      return $stdin.read
    elsif package_config_file.nil?
      if File.exist?(DEFAULT_FIG_FILE)
        return File.read(DEFAULT_FIG_FILE)
      end
    else
      return read_in_package_config_file(package_config_file)
    end

    return
  end

  def display_local_package_list(repository)
    repository.list_packages.sort.each do |item|
      puts item
    end
  end

  def display_remote_package_list(repository)
    repository.list_remote_packages.sort.each do |item|
      puts item
    end
  end

  def display_configs_in_local_packages_list(package)
    package.configs.each do |config|
      puts config.name
    end

    return
  end

  def handle_pre_parse_list_options(options, repository)
    case options[:listing]
    when :local_packages
      display_local_package_list(repository)
    when :remote_packages
      display_remote_package_list(repository)
    else
      return false
    end

    return true
  end

  def display_dependencies(environment)
    environment.packages.sort.each { |package| puts package }
  end

  def handle_post_parse_list_options(options, package, environment)
    case options[:listing]
    when :configs
      display_configs_in_local_packages_list(package)
    when :dependencies
      raise Fig::UserInputError.new('--list-dependencies not yet implemented.')
    when :dependencies_all_configs
      raise Fig::UserInputError.new('--list-dependencies-all-configs not yet implemented.')
    when :variables
      raise Fig::UserInputError.new('--list-variables not yet implemented.')
    when :variables_all_configs
      raise Fig::UserInputError.new('--list-variables-all-configs not yet implemented.')
    else
      raise %Q<Bug in code! Found unknown :listing option value "#{options[:listing]}">
    end

    return
  end

  def register_package_with_environment(options, package, environment)
    if options[:update] || options[:update_if_missing]
      package.retrieves.each do |var, path|
        environment.add_retrieve(var, path)
      end
    end

    environment.register_package(package)
    environment.apply_config(package, options[:config], nil)

    return
  end

  def parse_package_config_file(options, config_raw_text, environment, configuration)
    if config_raw_text.nil?
      return Fig::Package.new(nil, nil, '.', [])
    end

    package =
      Fig::Parser.new(configuration).parse_package(nil, nil, '.', config_raw_text)

    register_package_with_environment(options, package, environment)

    return package
  end

  def load_package_file(options, environment, configuration)
    config_raw_text = load_package_config_file_contents(options)

    return parse_package_config_file(
      options, config_raw_text, environment, configuration
    )
  end

  def load_package(descriptor, options, environment, repository, configuration)
    package = nil
    if descriptor.nil?
      package = load_package_file(options, environment, configuration)
    else
      # TODO: complain if config file was specified on the command-line.
      package =
        repository.read_local_package(descriptor.name, descriptor.version)

      register_package_with_environment(options, package, environment)
    end

    return package
  end

  def publish(descriptor, options, environment, repository, configuration)
    if not descriptor
      raise_package_descriptor_required('to publish')
    end

    if descriptor.name.nil? || descriptor.version.nil?
      $stderr.puts 'Please specify a package name and a version name.'
      return 10
    end

    if not options[:non_command_package_statements].empty?
      publish_statements =
        options[:resources] +
        options[:archives] +
        [
          Fig::Package::Configuration.new(
            'default', options[:non_command_package_statements]
          )
        ]
      publish_statements << Fig::Package::Publish.new('default','default')
    else
      package = load_package_file(options, environment, configuration)
      if not package.statements.empty?
        publish_statements = package.statements
      else
        $stderr.puts 'Nothing to publish.'
        return 1
      end
    end

    if options[:publish]
      Fig::Logging.info "Checking status of #{descriptor.name}/#{descriptor.version}..."

      if repository.list_remote_packages.include?("#{descriptor.name}/#{descriptor.version}")
        Fig::Logging.info "#{descriptor.name}/#{descriptor.version} has already been published."

        if not options[:force]
          Fig::Logging.fatal 'Use the --force option if you really want to overwrite, or use --publish-local for testing.'
          return 1
        else
          Fig::Logging.info 'Overwriting...'
        end
      end
    end

    Fig::Logging.info "Publishing #{descriptor.name}/#{descriptor.version}."
    repository.publish_package(publish_statements, descriptor.name, descriptor.version, options[:publish_local])

    return 0
  end

  def run_fig(argv)
    shell_command = initialize_shell_command(argv)

    options, descriptor, exit_value = Fig::Options.parse_options(argv)
    if not exit_value.nil?
      return exit_value
    end

    Fig::Logging.initialize_pre_configuration(options[:log_level])

    remote_url = initialize_remote_url(options)

    configuration = Fig::FigRC.find(
      options[:figrc], remote_url, options[:login], options[:home], options[:no_figrc]
    )

    Fig::Logging.initialize_post_configuration(options[:log_config] || configuration['log configuration'], options[:log_level])

    os = Fig::OS.new(options[:login])
    repository = Fig::Repository.new(
      os,
      File.expand_path(File.join(options[:home], 'repos')),
      remote_url,
      configuration,
      nil, # remote_user
      options[:update],
      options[:update_if_missing]
    )

    retriever = Fig::Retriever.new('.')

    # Check to see if this is still happening with the new layers of abstraction.
    at_exit { retriever.save }

    environment = Fig::Environment.new(os, repository, nil, retriever)

    options[:non_command_package_statements].each do |statement|
      environment.apply_config_statement(nil, statement, nil)
    end

    if options[:clean]
      # TODO: check descriptor was specified.
      repository.clean(descriptor.name, descriptor.version)
      return 0
    end

    if handle_pre_parse_list_options(options, repository)
      return 0
    end

    if options[:publish] || options[:publish_local]
      return publish(descriptor, options, environment, repository, configuration)
    end

    package =
      load_package(descriptor, options, environment, repository, configuration)

    if options[:listing]
      handle_post_parse_list_options(options, package, environment)
    elsif options[:get]
      puts environment[options[:get]]
    elsif shell_command
      environment.execute_shell(shell_command) { |cmd| os.shell_exec cmd }
    elsif descriptor
      environment.include_config(
        package, descriptor.name, descriptor.config, descriptor.version, {}, nil
      )
      environment.execute_config(
        package, descriptor.name, descriptor.config, nil, []
      ) { |cmd| os.shell_exec cmd }
    elsif not repository.updating?
      $stderr.puts "Nothing to do.\n"
      $stderr.puts Fig::Options::USAGE
      $stderr.puts %q<Run "fig --help" for a full list of commands.>
      return 1
    end

    return 0
  end

  def log_error_message(error)
    # If there's no message, we assume that the cause has already been logged.
    if error_has_message?(error)
      Fig::Logging.fatal error.to_s
    end
  end

  def run_with_exception_handling(argv)
    begin
      return_code = run_fig(argv)
      return return_code
    rescue Fig::URLAccessError => error
      urls = exception.urls.join(', ')
      $stderr.puts "Access to #{urls} in #{exception.package}/#{exception.version} not allowed."
      return 1
    rescue Fig::UserInputError => error
      log_error_message(error)
      return 1
    rescue OptionParser::InvalidOption => error
      $stderr.puts error.to_s
      $stderr.puts Fig::Options::USAGE
      return 1
    rescue Fig::RepositoryError => error
      log_error_message(error)
      return 1
    end
  end

  def error_has_message?(error)
    class_name = error.class.name
    return error.message != class_name
  end
end
