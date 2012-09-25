require 'fileutils'
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
require 'fig/update_lock'
require 'fig/user_input_error'
require 'fig/working_directory_maintainer'

module Fig; end

# Main program
class Fig::Command
  def run_fig(argv, options = nil)
    begin
      @options = options || Fig::Command::Options.new()
      @options.process_command_line(argv)
    rescue Fig::UserInputError => error
      $stderr.puts error.to_s # Logging isn't set up yet.
      return Fig::Command::Action::EXIT_FAILURE
    end

    if not @options.exit_code.nil?
      return @options.exit_code
    end

    Fig::Logging.initialize_pre_configuration(@options.log_level())

    actions = @options.actions()
    if actions.empty?
      return handle_nothing_to_do
    end

    actions.each do
      |action|

      if action.execute_immediately_after_command_line_parse?
        # Note that the action doesn't get an execution context.
        return action.execute()
      end
    end

    @descriptor = @options.descriptor
    check_descriptor_requirement()
    if actions.any? {|action| not action.allow_both_descriptor_and_file? }
      ensure_descriptor_and_file_were_not_both_specified()
    end
    check_package_content_options()

    configure()
    set_up_base_package()
    invoke_post_set_up_actions()

    context = ExecutionContext.new(
      @base_package,
      @synthetic_package_for_command_line,
      base_config(),
      @environment,
      @repository,
      @operating_system,
      @package_source_description,
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

  def run_fig_with_exception_handling(argv, options = nil)
    begin
      return run_fig(argv, options)
    rescue Fig::URLAccessDisallowedError => error
      urls = error.urls.join(', ')
      $stderr.puts \
        "Access to #{urls} in #{error.package}/#{error.version} not allowed."
    rescue Fig::UserInputError => error
      log_error_message(error)
    end

    return Fig::Command::Action::EXIT_FAILURE
  end

  # Extension mechanism for customizing Fig.
  def add_post_set_up_action(action)
    @post_set_up_actions << action

    return
  end

  def add_publish_listener(listener)
    @publish_listeners << listener

    return
  end

  def initialize()
    @post_set_up_actions = []
    @publish_listeners = []
  end

  private

  ExecutionContext =
    Struct.new(
      :base_package,
      :synthetic_package_for_command_line,
      :base_config,
      :environment,
      :repository,
      :operating_system,
      :package_source_description
    )

  def handle_nothing_to_do()
    command_statement = nil
    if ! @descriptor && @options.package_definition_file != :none
      load_base_package()
      config = base_config
      command_statement = @base_package[config].command_statement
    end

    $stderr.puts "Nothing to do.\n\n"

    if command_statement
      $stderr.puts \
        %Q<You have a command statement in the "#{config}" config.  If you want to run it, use the "--run-command-statement" option.\n\n>
    end

    $stderr.puts %q<Run "fig --help" for a full list of commands.>

    return Fig::Command::Action::EXIT_FAILURE
  end

  def check_include_statements_versions?()
    return false if @options.suppress_warning_include_statement_missing_version?

    suppressed_warnings = @application_configuration['suppress warnings']
    return true if not suppressed_warnings

    return ! suppressed_warnings.include?('include statement missing version')
  end

  def configure()
    set_up_update_lock()
    set_up_application_configuration()

    Fig::Logging.initialize_post_configuration(
      @options.log_config() || @application_configuration['log configuration'],
      @options.log_level()
    )

    @operating_system = Fig::OperatingSystem.new(@options.login?)

    prepare_repository()
    prepare_environment()
  end

  def set_up_update_lock()
    return if @options.actions.none? {|action| action.modifies_repository?}

    update_lock_response = @options.update_lock_response
    return if update_lock_response == :ignore

    if Fig::OperatingSystem.windows?
      if ! update_lock_response.nil?
        Fig::Logging.warn('At present, locking is not supported on Windows.')
      end

      return
    end

    @update_lock = Fig::UpdateLock.new(@options.home, update_lock_response)

    # *sigh* Ruby 1.8 doesn't support close_on_exec(), so we've got to ensure
    # this stuff on our own.
    Fig::AtExit.add { @update_lock.close }

    return
  end

  def set_up_application_configuration()
    @application_configuration = Fig::FigRC.find(
      @options.figrc(),
      ENV['FIG_REMOTE_URL'],
      @options.login?,
      @options.home(),
      @options.no_figrc?
    )

    if \
          remote_operation_necessary? \
      &&  @application_configuration.remote_repository_url.nil?

      raise Fig::UserInputError.new(
        'Please define the FIG_REMOTE_URL environment variable.'
      )
    end

    return
  end

  def prepare_repository()
    @repository = Fig::Repository.new(
      @operating_system,
      @options.home(),
      @application_configuration,
      @publish_listeners,
      check_include_statements_versions?
    )

    @options.actions.each {|action| action.prepare_repository(@repository)}

    return
  end

  def prepare_environment()
    working_directory_maintainer = Fig::WorkingDirectoryMaintainer.new('.')

    Fig::AtExit.add do
      working_directory_maintainer.prepare_for_shutdown(
        @base_package && retrieves_should_happen?
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
    return if ! load_base_package?

    # We get these before loading the package so that we detect conflicts
    # between actions.
    retrieves_should_happen = retrieves_should_happen?
    register_base_package   = register_base_package?
    apply_config            = apply_config?
    apply_base_config       = apply_config ? apply_base_config? : nil

    load_base_package()

    applier = new_package_applier()

    if retrieves_should_happen
      applier.activate_retrieves()
    end
    if register_base_package
      applier.register_package_with_environment()
    end
    if apply_config
      applier.apply_config_to_environment(! apply_base_config)
    end

    @synthetic_package_for_command_line =
      applier.synthetic_package_for_command_line

    return
  end

  def load_base_package()
    package_loader = new_package_loader()
    if @options.actions.all? {|action| action.base_package_can_come_from_descriptor?}
      @base_package = package_loader.load_package_object()
    else
      @base_package = package_loader.load_package_object_from_file()
    end
    @package_source_description = package_loader.package_source_description()

    return
  end

  def invoke_post_set_up_actions()
    @post_set_up_actions.each do
      |action|

      action.set_up_finished(@application_configuration)
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
      @application_configuration,
      @descriptor,
      @options.package_definition_file,
      base_config(),
      @repository
    )
  end

  def new_package_applier()
    return Fig::Command::PackageApplier.new(
      @base_package,
      @environment,
      @options,
      @descriptor,
      base_config(),
      @package_source_description
    )
  end

  # If the user has specified a descriptor and we are not publishing, than any
  # package.fig or --file option is ignored.  Thus, in order to avoid confusing
  # the user, we make specifying both an error.
  def ensure_descriptor_and_file_were_not_both_specified()
    file = @options.package_definition_file()

    # If the user specified --no-file, even though it's kind of superfluous,
    # we'll let it slide because the user doesn't think that any file will be
    # processed.
    file_specified = ! file.nil? && file != :none

    if @descriptor && file_specified
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

  def check_package_content_options()
    statements = @options.package_contents_statements
    return if statements.empty?

    return if @options.actions.any? \
      {|action| action.cares_about_package_content_options?}

    statements.each do
      |statement|

      Fig::Logging.warn(
        "Ignored #{statement.source_description} for #{statement.location}."
      )
    end

    return
  end

  def remote_operation_necessary?()
    return @options.actions.any? {|action| action.remote_operation_necessary?}
  end

  def load_base_package?()
    return should_perform?(
      @options.actions, %Q<the base package should be loaded>
    ) {|action| action.load_base_package?}
  end

  def retrieves_should_happen?()
    return @options.actions.any? {|action| action.retrieves_should_happen?}
  end

  def register_base_package?()
    return should_perform?(
      @options.actions, %Q<the base package should be in the starting set of packages>
    ) {|action| action.register_base_package?}
  end

  def apply_config?()
    return should_perform?(
      @options.actions, %Q<any config should be applied>
    ) {|action| action.apply_config?}
  end

  def apply_base_config?()
    actions_wanting_application =
      @options.actions.select {|action| action.apply_config?}

    return should_perform?(
      actions_wanting_application, %Q<the base config should be applied>
    ) {|action| action.apply_base_config?}
  end

  def should_perform?(actions, failure_description, &predicate)
    yes_actions, no_actions = actions.partition &predicate
    # Filter out the "don't care" actions".
    no_actions = no_actions.select { |action| ! predicate.call(action).nil?  }

    return false if yes_actions.empty?
    return true if no_actions.empty?

    action_strings = actions.map {|action| action.options.join}
    action_string = action_strings.join %q<", ">
    raise Fig::UserInputError.new(
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
