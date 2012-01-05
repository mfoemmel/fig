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

# Main program
module Fig
  DEFAULT_FIG_FILE = 'package.fig'

  def parse_descriptor(descriptor)
    # todo should use treetop for these:
    package_name = descriptor =~ %r< ^ ( [^:/]+ ) >x ? $1 : nil
    config_name  = descriptor =~ %r< : ( [^:/]+ ) >x ? $1 : nil
    version_name = descriptor =~ %r< / ( [^:/]+ ) >x ? $1 : nil
    return package_name, config_name, version_name
  end

  def read_in_package_config_file(options)
    if File.exist?(options[:package_config_file])
      return File.read(options[:package_config_file])
    else
      raise UserInputError.new(%Q<File not found: "#{options[:package_config_file]}".>)
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
        raise UserInputError.new('Please define the FIG_REMOTE_URL environment variable.')
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
      return read_in_package_config_file(options)
    end
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

  def display_configs_in_local_packages_list(options, repository)
    options[:list_configs].each do |descriptor|
      if descriptor !~ %r< / >x
        raise UserInputError.new(
          %Q<Package "#{descriptor}" does not contain a version.>
        )
      end

      package_name, version_name = descriptor.split('/')
      repository.read_local_package(package_name, version_name).configs.each do |config|
        puts config.name
      end
    end
  end

  def resolve_listing(options, repository)
    case options[:listing]
    when :local_packages
      display_local_package_list(repository)
    when :remote_packages
      display_remote_package_list(repository)
    when :configs
      display_configs_in_local_packages_list(options, repository)
    when :dependencies
      raise UserInputError.new('--list-dependencies not yet implemented.')
    when :all_variables
      raise UserInputError.new('--list-all-variables not yet implemented.')
    else
      return false
    end

    return true
  end

  def parse_package_config_file(options, package_config_file, environment, configuration)
    if package_config_file
      package = Parser.new(configuration).parse_package(nil, nil, '.', package_config_file)
      if options[:update] || options[:update_if_missing]
        package.retrieves.each do |var, path|
          environment.add_retrieve(var, path)
        end
      end

      unless options[:publish] || options[:list] || options[:publish_local]
        environment.register_package(package)
        environment.apply_config(package, options[:config], nil)
      end
    else
      package = Package.new(nil, nil, '.', [])
    end

    return package, environment
  end

  def publish(argv, options, package, repository)
    if not argv.empty?
      $stderr.puts %Q<Unexpected arguments: #{argv.join(' ')}>
      return 10
    end

    package_name, config_name, version_name = parse_descriptor(options[:publish] || options[:publish_local])

    if package_name.nil? || version_name.nil?
      $stderr.puts 'Please specify a package name and a version name.'
      return 10
    end

    if not options[:non_command_package_statements].empty?
      publish_statements =
        options[:resources] +
        options[:archives] +
        [
          Package::Configuration.new(
            'default', options[:non_command_package_statements]
          )
        ]
      publish_statements << Package::Publish.new('default','default')
    elsif not package.statements.empty?
      publish_statements = package.statements
    else
      $stderr.puts 'Nothing to publish.'
      return 1
    end

    if options[:publish]
      Logging.info "Checking status of #{package_name}/#{version_name}..."

      if repository.list_remote_packages.include?("#{package_name}/#{version_name}")
        Logging.info "#{package_name}/#{version_name} has already been published."

        if not options[:force]
          Logging.fatal 'Use the --force option if you really want to overwrite, or use --publish-local for testing.'
          return 1
        else
          Logging.info 'Overwriting...'
        end
      end
    end

    Logging.info "Publishing #{package_name}/#{version_name}."
    repository.publish_package(publish_statements, package_name, version_name, options[:publish_local])

    return 0
  end

  def run_fig(argv)
    shell_command = initialize_shell_command(argv)

    options, argv, exit_value = parse_options(argv)
    if not exit_value.nil?
      return exit_value
    end

    Logging.initialize_pre_configuration(options[:log_level])

    remote_url = initialize_remote_url(options)

    configuration = FigRC.find(
      options[:figrc], remote_url, options[:login], options[:home], options[:no_figrc]
    )

    Logging.initialize_post_configuration(options[:log_config] || configuration['log configuration'], options[:log_level])

    os = OS.new(options[:login])
    repository = Repository.new(
      os,
      File.expand_path(File.join(options[:home], 'repos')),
      remote_url,
      configuration,
      nil, # remote_user
      options[:update],
      options[:update_if_missing]
    )

    retriever = Retriever.new('.')
    # Check to see if this is still happening with the new layers of abstraction.
    at_exit { retriever.save }
    environment = Environment.new(os, repository, nil, retriever)

    options[:non_command_package_statements].each do |statement|
      environment.apply_config_statement(nil, statement, nil)
    end

    package_config_file = load_package_config_file_contents(options)

    options[:cleans].each do |descriptor|
      package_name, version_name = descriptor.split('/')
      repository.clean(package_name, version_name)
      return true
    end

    if resolve_listing(options, repository)
      return true
    end

    package, environment = parse_package_config_file(options, package_config_file, environment, configuration)

    if options[:publish] || options[:publish_local]
      return publish(argv, options, package, repository)
    elsif options[:get]
      puts environment[options[:get]]
    elsif shell_command
      argv.shift
      environment.execute_shell(shell_command) { |cmd| os.shell_exec cmd }
    elsif not argv.empty?
      package_name, config_name, version_name = parse_descriptor(argv.shift)
      environment.include_config(package, package_name, config_name, version_name, {}, nil)
      environment.execute_config(package, package_name, config_name, nil, argv) { |cmd| os.shell_exec cmd }
    elsif not repository.updating?
      $stderr.puts "Nothing to do.\n"
      $stderr.puts USAGE
      $stderr.puts %q<Run "fig --help" for a full list of commands.>
      return 1
    end

    return 0
  end

  def log_error_message(error)
    # If there's no message, we assume that the cause has already been logged.
    if error_has_message?(error)
      Logging.fatal error.to_s
    end
  end

  def run_with_exception_handling(argv)
    begin
      return_code = run_fig(argv)
      return return_code
    rescue URLAccessError => error
      urls = exception.urls.join(', ')
      $stderr.puts "Access to #{urls} in #{exception.package}/#{exception.version} not allowed."
      return 1
    rescue UserInputError => error
      log_error_message(error)
      return 1
    rescue OptionParser::InvalidOption => error
      $stderr.puts error.to_s
      $stderr.puts USAGE
      return 1
    rescue RepositoryError => error
      log_error_message(error)
      return 1
    end
  end

  def error_has_message?(error)
    class_name = error.class.name
    return error.message != class_name
  end
end
