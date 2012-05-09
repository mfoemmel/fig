require 'rubygems'
require 'net/ftp'
require 'set'

require 'fig/atexit'
require 'fig/command/options'
require 'fig/environment'
require 'fig/figrc'
require 'fig/logging'
require 'fig/operatingsystem'
require 'fig/package'
require 'fig/parser'
require 'fig/repository'
require 'fig/repositoryerror'
require 'fig/statement/configuration'
require 'fig/userinputerror'
require 'fig/workingdirectorymaintainer'

# These are a breakout of parts of this class simply to keep the file size down.

# You will need to look in this file for any stuff related to --list-* options.
require 'fig/command/listing'

# You will need to look in this file for any stuff related to loading the
# primary Package object.
require 'fig/command/packageload'

module Fig; end

# Main program
class Fig::Command
  include Fig::Command::Listing
  include Fig::Command::PackageLoad

  def self.get_version()
    line = nil

    begin
      File.open(
        "#{File.expand_path(File.dirname(__FILE__) + '/../../VERSION')}"
      ) do |file|
        line = file.gets
      end
    rescue
      $stderr.puts 'Could not retrieve version number. Something has mucked with your Fig install.'

      return nil
    end

    # Note that we accept anything that contains three decimal numbers
    # seperated by periods.  This allows for versions like
    # "4.3.2-super-special-version-in-3D".
    if line !~ %r< \b \d+ [.] \d+ [.] \d+ \b >x
      $stderr.puts %Q<"#{line}" does not look like a version number. Something has mucked with your Fig install.>

      return nil
    end

    return line
  end

  def run_fig(argv)
    @options = Fig::Command::Options.new(argv)
    if not @options.exit_code.nil?
      return @options.exit_code
    end
    @descriptor = @options.descriptor

    if @options.help?
      return @options.help
    end

    if @options.version?
      return emit_version()
    end

    configure()

    if @options.clean?
      check_required_package_descriptor('to clean')
      ensure_descriptor_and_file_were_not_both_specified()
      @repository.clean(@descriptor)
      return 0
    end

    if handle_pre_parse_list_options()
      return 0
    end

    if @options.publishing?
      return publish()
    end

    ensure_descriptor_and_file_were_not_both_specified()
    load_package_object()

    if @options.listing()
      handle_post_parse_list_options()
    elsif @options.get()
      puts @environment[@options.get()]
    elsif @options.shell_command
      @environment.execute_shell(@options.shell_command) do
        |command| @operating_system.shell_exec command
      end
    elsif @descriptor
      @environment.include_config(@package, @descriptor, nil)
      @environment.execute_config(
        @package,
        @descriptor,
        @options.command_extra_argv || []
      ) { |cmd| @operating_system.shell_exec cmd }
    elsif not @repository.updating?
      $stderr.puts "Nothing to do.\n\n"
      $stderr.puts %q<Run "fig --help" for a full list of commands.>
      return 1
    end

    return 0
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
      $stderr.puts Fig::Command::Options::USAGE
      return 1
    rescue Fig::RepositoryError => error
      log_error_message(error)
      return 1
    end
  end

  def emit_version()
    version = Fig::Command.get_version()
    return 1 if version.nil?

    puts File.basename($0) + ' v' + version

    return 0
  end

  private

  def derive_remote_url()
    if remote_operation_necessary?()
      if ENV['FIG_REMOTE_URL'].nil?
        raise Fig::UserInputError.new('Please define the FIG_REMOTE_URL environment variable.')
      end
      return ENV['FIG_REMOTE_URL']
    end

    return nil
  end

  def check_include_statements_versions?()
    return false if @options.suppress_warning_include_statement_missing_version?

    suppressed_warnings = @configuration['suppress warnings']
    return true if not suppressed_warnings

    return ! suppressed_warnings.include?('include statement missing version')
  end

  def configure()
    Fig::Logging.initialize_pre_configuration(@options.log_level())


    @configuration = Fig::FigRC.find(
      @options.figrc(),
      derive_remote_url(),
      @options.login?,
      @options.home(),
      @options.no_figrc?
    )

    Fig::Logging.initialize_post_configuration(
      @options.log_config() || @configuration['log configuration'],
      @options.log_level()
    )

    @operating_system = Fig::OperatingSystem.new(@options.login?)
    @repository = Fig::Repository.new(
      @operating_system,
      @options.home(),
      @configuration,
      nil, # remote_user
      @options.update?,
      @options.update_if_missing?,
      check_include_statements_versions?
    )

    @working_directory_maintainer = Fig::WorkingDirectoryMaintainer.new('.')

    Fig::AtExit.add do
      @working_directory_maintainer.prepare_for_shutdown(@options.updating?)
    end

    prepare_environment()

    @options.environment_variable_statements().each do |statement|
      @environment.apply_config_statement(nil, statement, nil)
    end
  end

  def prepare_environment()
    environment_variables = nil
    if @options.reset_environment?
      environment_variables = Fig::OperatingSystem.get_environment_variables({})
    end

    @environment = Fig::Environment.new(
      @repository, environment_variables, @working_directory_maintainer
    )

    Fig::AtExit.add { @environment.check_unused_retrieves() }

    return
  end

  def config_was_specified_by_user()
    return ! @options.config().nil?                   ||
           @descriptor && ! @descriptor.config().nil?
  end

  def base_config()
    return @options.config()                 ||
           @descriptor && @descriptor.config ||
           Fig::Package::DEFAULT_CONFIG
  end

  # If the user has specified a descriptor, than any package.fig or --file
  # option is ignored.  Thus, in order to avoid confusing the user, we make
  # specifying both an error.
  #
  # The one exception to this rule is when we are publishing, which should
  # already have been invoked by the time this is called.
  def ensure_descriptor_and_file_were_not_both_specified()
    file = @options.package_config_file()

    # If the user specified --no-file, even though it's kind of superfluous,
    # we'll let it slide because the user doesn't think that any file will be
    # processed.
    file_specified = ! file.nil? && file != :none

    if @descriptor and file_specified
      raise Fig::UserInputError.new(
        %Q<Cannot specify both a package descriptor (#{@descriptor.original_string}) and the --file option (#{file}).>
      )
    end

    return
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

  def remote_operation_necessary?()
    return @options.updating?                     ||
           @options.publish?                      ||
           @options.listing == :remote_packages
  end

  def publish()
    check_required_package_descriptor('to publish')

    if @descriptor.name.nil? || @descriptor.version.nil?
      raise Fig::UserInputError.new(
        'Please specify a package name and a version name.'
      )
    end
    if @descriptor.name == '_meta'
      raise Fig::UserInputError.new(
        %q<Due to implementation issues, cannot create a package named "_meta".>
      )
    end

    publish_statements = nil
    if not @options.environment_variable_statements().empty?
      publish_statements =
        @options.resources() +
        @options.archives() +
        [
          Fig::Statement::Configuration.new(
            nil,
            nil,
            Fig::Package::DEFAULT_CONFIG,
            @options.environment_variable_statements()
          )
        ]
    elsif not @options.resources().empty? or not @options.archives().empty?
      raise Fig::UserInputError.new(
        '--resource/--archive options were specified, but no --set/--append option was given. Will not publish.'
      )
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
      Fig::Logging.info "Checking status of #{@descriptor.to_string()}..."

      package_description =
        Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, nil)
      if @repository.list_remote_packages.include?("#{package_description}")
        Fig::Logging.info "#{@descriptor.to_string()} has already been published."

        if not @options.force?
          Fig::Logging.fatal 'Use the --force option if you really want to overwrite, or use --publish-local for testing.'
          return 1
        else
          Fig::Logging.info 'Overwriting...'
        end
      end
    end

    Fig::Logging.info "Publishing #{@descriptor.to_string()}."
    @repository.publish_package(
      publish_statements, @descriptor, @options.publish_local?
    )

    return 0
  end

  def log_error_message(error)
    # If there's no message, we assume that the cause has already been logged.
    if error_has_message?(error)
      Fig::Logging.fatal error.to_s
    end
  end

  def error_has_message?(error)
    class_name = error.class.name
    return error.message != class_name
  end
end
