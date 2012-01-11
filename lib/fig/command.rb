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

  def derive_remote_url()
    if remote_operation_necessary?()
      if ENV['FIG_REMOTE_URL'].nil?
        raise Fig::UserInputError.new('Please define the FIG_REMOTE_URL environment variable.')
      end
      return ENV['FIG_REMOTE_URL']
    end

    return nil
  end

  def configure()
    Fig::Logging.initialize_pre_configuration(@options.log_level())

    remote_url = derive_remote_url()

    @configuration = Fig::FigRC.find(
      @options.figrc(),
      remote_url,
      @options.login?,
      @options.home(),
      @options.no_figrc?
    )

    Fig::Logging.initialize_post_configuration(
      @options.log_config() || @configuration['log configuration'],
      @options.log_level()
    )

    @os = Fig::OS.new(@options.login?)
    @repository = Fig::Repository.new(
      @os,
      File.expand_path(File.join(@options.home(), 'repos')),
      remote_url,
      @configuration,
      nil, # remote_user
      @options.update?,
      @options.update_if_missing?
    )

    @retriever = Fig::Retriever.new('.')

    # Check to see if this is still happening with the new layers of abstraction.
    at_exit { @retriever.save }

    @environment = Fig::Environment.new(@os, @repository, nil, @retriever)

    @options.non_command_package_statements().each do |statement|
      @environment.apply_config_statement(nil, statement, nil)
    end
  end

  def check_required_package_descriptor(operation_description)
    if not @descriptor
      raise Fig::UserInputError.new(
        "Need to specify a package #{operation_description}."
      )
    end

    return
  end

  def check_disallowed_package_descriptor(operation_description)
    if @descriptor
      raise Fig::UserInputError.new(
        "Cannot specify a package for #{operation_description}."
      )
    end
  end

  def read_in_package_config_file(config_file)
    if File.exist?(config_file)
      return File.read(config_file)
    else
      raise Fig::UserInputError.new(%Q<File not found: "#{config_file}".>)
    end
  end

  def remote_operation_necessary?()
    return @options.updating?                     ||
           @options.publish?                      ||
           @options.listing == :remote_packages
  end

  def load_package_config_file_contents()
    package_config_file = @options.package_config_file()

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
    packages = @environment.packages.sort { |a, b| a.package_name <=> b.package_name }
    if packages.empty? and $stdout.tty?
      puts '<no dependencies>'
    else
      packages.each { |package| puts package }
    end

    return
  end

  def handle_post_parse_list_options()
    case @options.listing()
    when :configs
      display_configs_in_local_packages_list()
    when :dependencies
      display_dependencies()
    when :dependencies_all_configs
      raise Fig::UserInputError.new('--list-dependencies-all-configs not yet implemented.')
    when :variables
      raise Fig::UserInputError.new('--list-variables not yet implemented.')
    when :variables_all_configs
      raise Fig::UserInputError.new('--list-variables-all-configs not yet implemented.')
    else
      raise %Q<Bug in code! Found unknown :listing option value "#{options.listing()}">
    end

    return
  end

  def register_package_with_environment()
    if @options.updating?
      @package.retrieves.each do |var, path|
        @environment.add_retrieve(var, path)
      end
    end

    @environment.register_package(@package)
    @environment.apply_config(@package, @options.config(), nil)

    return
  end

  def parse_package_config_file(config_raw_text)
    if config_raw_text.nil?
      @package = Fig::Package.new(nil, nil, '.', [])
      return
    end

    @package =
      Fig::Parser.new(@configuration).parse_package(
        nil, nil, '.', config_raw_text
      )

    register_package_with_environment()

    return
  end

  def load_package_file()
    config_raw_text = load_package_config_file_contents()

    parse_package_config_file(config_raw_text)
  end

  def load_package()
    if @descriptor.nil?
      @package = load_package_file()
    else
      # TODO: complain if config file was specified on the command-line.
      @package =
        @repository.read_local_package(@descriptor.name, @descriptor.version)

      register_package_with_environment()
    end

    return
  end

  def publish()
    check_required_package_descriptor('to publish')

    if @descriptor.name.nil? || @descriptor.version.nil?
      raise Fig::UserInputError.new('Please specify a package name and a version name.')
    end

    if not @options.non_command_package_statements().empty?
      publish_statements =
        @options.resources() +
        @options.archives() +
        [
          Fig::Package::Configuration.new(
            'default', @options.non_command_package_statements()
          )
        ]
      publish_statements << Fig::Package::Publish.new('default','default')
    else
      load_package_file()
      if not @package.statements.empty?
        publish_statements = @package.statements
      else
        $stderr.puts 'Nothing to publish.'
        return 1
      end
    end

    if @options.publish?
      Fig::Logging.info "Checking status of #{@descriptor.name}/#{@descriptor.version}..."

      if @repository.list_remote_packages.include?("#{@descriptor.name}/#{@descriptor.version}")
        Fig::Logging.info "#{@descriptor.name}/#{@descriptor.version} has already been published."

        if not @options.force?
          Fig::Logging.fatal 'Use the --force option if you really want to overwrite, or use --publish-local for testing.'
          return 1
        else
          Fig::Logging.info 'Overwriting...'
        end
      end
    end

    Fig::Logging.info "Publishing #{@descriptor.name}/#{@descriptor.version}."
    @repository.publish_package(
      publish_statements,
      @descriptor.name,
      @descriptor.version,
      @options.publish_local?
    )

    return 0
  end

  def run_fig(argv)
    @options = Fig::Options.new(argv)
    if not @options.exit_code.nil?
      return @options.exit_code
    end
    @descriptor = @options.descriptor

    configure

    if @options.clean?
      check_required_package_descriptor('to clean')
      @repository.clean(@descriptor.name, @descriptor.version)
      return 0
    end

    if handle_pre_parse_list_options()
      return 0
    end

    if @options.publishing?
      return publish()
    end

    load_package()

    if @options.listing()
      handle_post_parse_list_options()
    elsif @options.get()
      puts @environment[@options.get()]
    elsif @options.shell_command
      @environment.execute_shell(@options.shell_command) do
        |command| @os.shell_exec command
      end
    elsif @descriptor
      @environment.include_config(
        @package, @descriptor.name, @descriptor.config, @descriptor.version, {}, nil
      )
      @environment.execute_config(
        @package, @descriptor.name, @descriptor.config, nil, []
      ) { |cmd| @os.shell_exec cmd }
    elsif not @repository.updating?
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
      urls = error.urls.join(', ')
      $stderr.puts "Access to #{urls} in #{error.package}/#{error.version} not allowed."
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
