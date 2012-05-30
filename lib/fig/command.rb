require 'rubygems'
require 'net/ftp'
require 'set'

require 'fig/at_exit'
require 'fig/command/action'
require 'fig/command/options'
require 'fig/command/package_applier'
require 'fig/command/package_loader'
require 'fig/figrc'
require 'fig/logging'
require 'fig/operating_system'
require 'fig/package'
require 'fig/parser'
require 'fig/repository'
require 'fig/repository_error'
require 'fig/runtime_environment'
require 'fig/statement/configuration'
require 'fig/user_input_error'
require 'fig/working_directory_maintainer'

module Fig; end

# Main program
class Fig::Command
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
    begin
      @options = Fig::Command::Options.new(argv)
    rescue Fig::UserInputError => error
      $stderr.puts error.to_s # Logging isn't set up yet.
      return Fig::Command::Action::EXIT_FAILURE
    end

    if not @options.exit_code.nil?
      return @options.exit_code
    end

    actions = @options.actions()
    if actions.empty?
      $stderr.puts "Nothing to do.\n\n"
      $stderr.puts %q<Run "fig --help" for a full list of commands.>
      return Fig::Command::Action::EXIT_FAILURE
    end

    actions.each do
      |action|

      if action.execute_immediately_after_command_line_parse?
        # Note that the action doesn't get an execution context.
        return action.execute()
      end
    end

    Fig::Logging.initialize_pre_configuration(@options.log_level())

    @descriptor = @options.descriptor
    check_descriptor_requirement()
    if actions.any? {|action| not action.allow_both_descriptor_and_file? }
      ensure_descriptor_and_file_were_not_both_specified()
    end

    configure()
    set_up_base_package()

    context = ExecutionContext.new(
      @base_package,
      base_config(),
      @environment,
      @repository,
      @operating_system
    )

    actions.each do
      |action|

      action.execution_context = context

      exit_code = action.execute
      if exit_code != Fig::Command::Action::EXIT_SUCCESS
        return exit_code
      end
    end

    return Fig::Command::Action::EXIT_SUCCESS
  end

  def run_with_exception_handling(argv)
    begin
      return_code = run_fig(argv)
      return return_code
    rescue Fig::URLAccessError => error
      urls = error.urls.join(', ')
      $stderr.puts "Access to #{urls} in #{error.package}/#{error.version} not allowed."
      return Fig::Command::Action::EXIT_FAILURE
    rescue Fig::UserInputError => error
      log_error_message(error)
      return Fig::Command::Action::EXIT_FAILURE
    rescue OptionParser::InvalidOption => error
      $stderr.puts error.to_s
      $stderr.puts Fig::Command::Options::USAGE
      return Fig::Command::Action::EXIT_FAILURE
    rescue Fig::RepositoryError => error
      log_error_message(error)
      return Fig::Command::Action::EXIT_FAILURE
    end
  end

  private

  # Wanted: Better name for this.
  ExecutionContext =
    Struct.new(
      :base_package, :base_config, :environment, :repository, :operating_system
    )

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
    set_up_application_configuration()

    Fig::Logging.initialize_post_configuration(
      @options.log_config() || @configuration['log configuration'],
      @options.log_level()
    )

    @operating_system = Fig::OperatingSystem.new(@options.login?)

    prepare_repository()
    prepare_environment()
  end

  def set_up_application_configuration()
    @configuration = Fig::FigRC.find(
      @options.figrc(),
      derive_remote_url(),
      @options.login?,
      @options.home(),
      @options.no_figrc?
    )

    return
  end

  def prepare_repository()
    @repository = Fig::Repository.new(
      @operating_system,
      @options.home(),
      @configuration,
      nil, # remote_user
      @options.update?,
      @options.update_if_missing?,
      check_include_statements_versions?
    )

    return
  end

  def prepare_environment()
    working_directory_maintainer = Fig::WorkingDirectoryMaintainer.new('.')

    Fig::AtExit.add do
      working_directory_maintainer.prepare_for_shutdown(
        retrieves_should_happen?
      )
    end

    environment_variables = nil
    if reset_environment?
      environment_variables = Fig::OperatingSystem.get_environment_variables({})
    end

    @environment = Fig::RuntimeEnvironment.new(
      @repository, environment_variables, working_directory_maintainer
    )

    Fig::AtExit.add { @environment.check_unused_retrieves() }

    return
  end

  def set_up_base_package()
    actions = @options.actions.select {|action| action.need_base_package?}
    return if actions.empty?

    package_loader = new_package_loader()
    if actions.all? {|action| action.base_package_can_come_from_descriptor?}
      @base_package = package_loader.load_package_object()
    else
      @base_package = package_loader.load_package_object_from_file()
    end

    applier = new_package_applier(package_loader.package_source_description())

    if retrieves_should_happen?
      applier.activate_retrieves()
    end
    if register_base_package?(actions)
      applier.register_package_with_environment()
    end
    if apply_config?(actions)
      applier.apply_config_to_environment(! apply_base_config?(actions))
    end

    return
  end

  def base_config()
    return @options.config()                 ||
           @descriptor && @descriptor.config ||
           Fig::Package::DEFAULT_CONFIG
  end

  def new_package_loader()
    return Fig::Command::PackageLoader.new(
      @configuration,
      @descriptor,
      @options.package_definition_file,
      base_config(),
      @repository
    )
  end

  def new_package_applier(package_source_description)
    return Fig::Command::PackageApplier.new(
      @base_package,
      @environment,
      @options,
      @descriptor,
      base_config(),
      package_source_description
    )
  end

  # If the user has specified a descriptor, than any package.fig or --file
  # option is ignored.  Thus, in order to avoid confusing the user, we make
  # specifying both an error.
  def ensure_descriptor_and_file_were_not_both_specified()
    file = @options.package_definition_file()

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

  def check_descriptor_requirement()
    @options.actions.each do
      |action|

      case action.descriptor_requirement()
      when :required
        if not @descriptor
          raise Fig::UserInputError.new(
            "Need to specify a descriptor for #{action.primary_option()}."
          )
        end
      when :warn
        if @descriptor
          Fig::Logging.warn(
            %Q<Ignored descriptor "#{@descriptor.to_string}".>
          )
        end
      end
    end

    return
  end

  def remote_operation_necessary?()
    return @options.actions.any? {|action| action.remote_operation_necessary?}
  end

  def retrieves_should_happen?()
    return @options.actions.any? {|action| action.retrieves_should_happen?}
  end

  def register_base_package?(actions)
    return should_perform?(
      actions, %Q<the base package should be in the starting set of packages>
    ) {|action| action.register_base_package?}
  end

  def apply_config?(actions)
    return should_perform?(
      actions, %Q<any config should be applied>
    ) {|action| action.apply_config?}
  end

  def apply_base_config?(actions)
    return should_perform?(
      actions, %Q<the base config should be applied>
    ) {|action| action.apply_base_config?}
  end

  def should_perform?(actions, failure_description, &predicate)
    yes_actions, no_actions = actions.partition &predicate

    return false if yes_actions.empty?
    return true if no_actions.empty?

    action_strings = actions.map {|action| action.options.join}
    action_string = action_strings.join %q<", ">
    raise UserInputError.new(
      %Q<Cannot use "#{action_string}" together because they disagree on whether #{failure_description}.>
    )
  end

  def reset_environment?()
    return @options.actions.any? {|action| action.reset_environment?}
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
