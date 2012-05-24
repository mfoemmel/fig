require 'optparse'

require 'fig/command/action/clean'
require 'fig/command/action/get'
require 'fig/command/action/help'
require 'fig/command/action/list_configs'
require 'fig/command/action/list_dependencies'
require 'fig/command/action/list_dependencies/all_configs'
require 'fig/command/action/list_dependencies/default'
require 'fig/command/action/list_dependencies/tree'
require 'fig/command/action/list_dependencies/tree_all_configs'
require 'fig/command/action/list_local'
require 'fig/command/action/list_remote'
require 'fig/command/action/list_variables'
require 'fig/command/action/list_variables/all_configs'
require 'fig/command/action/list_variables/default'
require 'fig/command/action/list_variables/tree'
require 'fig/command/action/list_variables/tree_all_configs'
require 'fig/command/action/publish'
require 'fig/command/action/publish_local'
require 'fig/command/action/run_command_line'
require 'fig/command/action/run_command_statement'
require 'fig/command/action/update'
require 'fig/command/action/update_if_missing'
require 'fig/command/action/version'
require 'fig/command/option_error'
require 'fig/package'
require 'fig/package_descriptor'
require 'fig/statement/archive'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/set'

module Fig; end
class Fig::Command; end

# Command-line processing.
class Fig::Command::Options
  USAGE = <<-EOF
Usage:

  fig [...] [DESCRIPTOR] [--update | --update-if-missing] [-- COMMAND]
  fig [...] [DESCRIPTOR] [--update | --update-if-missing] [--command-extra-args VALUES]

  fig {--publish | --publish-local} DESCRIPTOR
      [--resource PATH]
      [--archive  PATH]
      [--include  DESCRIPTOR]
      [--override DESCRIPTOR]
      [--force]
      [...]

  fig --clean DESCRIPTOR [...]

  fig --get VARIABLE                                         [DESCRIPTOR] [...]
  fig --list-configs                                         [DESCRIPTOR] [...]
  fig --list-dependencies [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig --list-variables [--list-tree] [--list-all-configs]    [DESCRIPTOR] [...]
  fig {--list-local | --list-remote}                                      [...]

  fig {--version | --help}


A DESCRIPTOR looks like <package name>[/<version>][:<config>] e.g. "foo",
"foo/1.2.3", and "foo/1.2.3:default". Whether ":<config>" and "/<version>" are
required or allowed is dependent upon what your are doing.

Standard options (represented as "[...]" above):

      [--set    VARIABLE=VALUE]
      [--append VARIABLE=VALUE]
      [--file PATH] [--no-file]
      [--config CONFIG]
      [--login]
      [--log-level LEVEL] [--log-config PATH]
      [--figrc PATH] [--no-figrc]
      [--suppress-warning-include-statement-missing-version]

Environment variables:

  FIG_REMOTE_URL (required),
  FIG_HOME (path to local repository cache, defaults to $HOME/.fighome).
  EOF

  LOG_LEVELS = %w[ off fatal error warn info debug all ]
  LOG_ALIASES = { 'warning' => 'warn' }

  attr_reader :shell_command
  attr_reader :command_extra_argv
  attr_reader :descriptor
  attr_reader :exit_code

  def initialize(argv)
    process_command_line(argv)
  end

  def actions()
    actions = []

    if @update_action
      actions << @update_action
    end
    if @base_action
      actions << @base_action
    end

    return actions
  end

  # TODO: delete this once everything has been moved over to Actions.
  def base_action()
    return @base_action
  end

  def archives()
    return @options[:archives]
  end

  def clean?()
    return @options[:clean]
  end

  def config()
    return @options[:config]
  end

  def figrc()
    return @options[:figrc]
  end

  def force?()
    return @options[:force]
  end

  def get()
    return @options[:get]
  end

  def help?()
    return @options[:help]
  end

  def home()
    return @options[:home]
  end

  def listing()
    return @options[:listing]
  end

  def list_tree?()
    return @options[:list_tree]
  end

  def list_all_configs?()
    return @options[:list_all_configs]
  end

  def log_config()
    return @options[:log_config]
  end

  def login?()
    return @options[:login]
  end

  def log_level()
    return @options[:log_level]
  end

  def no_figrc?()
    return @options[:no_figrc]
  end

  def environment_statements()
    return @options[:environment_statements]
  end

  def package_definition_file()
    return @options[:package_definition_file]
  end

  def publish?()
    return @options[:publish]
  end

  def publish_local?()
    return @options[:publish_local]
  end

  def publishing?()
    return publish? || publish_local?
  end

  def resources()
    return @options[:resources]
  end

  def suppress_warning_include_statement_missing_version?()
    return @options[:suppress_warning_include_statement_missing_version]
  end

  def update?()
    return @options[:update]
  end

  def update_if_missing?()
    return @options[:update_if_missing]
  end

  def updating?()
    return update? || update_if_missing?
  end

  def version?()
    return @options[:version]
  end

  # Answers whether we should reset the environment to nothing, sort of like
  # the standardized environment that cron(1) creates.  At present, we're only
  # setting this when we're listing variables.  One could imagine allowing this
  # to be set by a command-line option in general; if we do this, the
  # Environment class will need to be changed to support deletion of values
  # from ENV.
  def reset_environment?()
    return listing() == :variables
  end

  # This needs to be public for efficient use of custom command.rb wrappers.
  def strip_shell_command(argv)
    argv.each_with_index do |arg, i|
      terminating_option = nil

      case arg
        when '--'
          set_base_action(Fig::Command::Action::RunCommandLine)
          @shell_command = argv[(i+1)..-1]
        when '--command-extra-args'
          set_base_action(Fig::Command::Action::RunCommandStatement)
          @command_extra_argv = argv[(i+1)..-1]
      end

      if @base_action
        argv.slice!(i..-1)
        break
      end
    end

    return
  end

  def help_message()
    return @help_message + <<-'END_MESSAGE'
        --                           end of Fig options; anything after this is used as a command to run
        --command-extra-args         end of Fig options; anything after this is appended to the end of a
                                     "command" statement in a "config" block.

    END_MESSAGE
  end

  private

  # Note that OptionParser insist that the regex match the entire value, not
  # just matches the regex in general.  In effect, OptionParser is wrapping the
  # regex with "\A" and "\z".
  STARTS_WITH_NON_HYPHEN = %r< \A [^-] .* >x

  ARGUMENT_DESCRIPTION = {
    '--set'    => Fig::Statement::Set::ARGUMENT_DESCRIPTION,
    '--append' => Fig::Statement::Path::ARGUMENT_DESCRIPTION
  }

  def process_command_line(argv)
    argv = argv.clone
    strip_shell_command(argv)

    @switches = []
    @options = {}

    @options[:home] = ENV['FIG_HOME'] || File.expand_path('~/.fighome')

    parser = new_parser()
    @help_message = parser.help

    begin
      parser.parse!(argv)
    rescue OptionParser::InvalidArgument => error
      raise_invalid_argument(error.args[0], error.args[1])
    rescue OptionParser::MissingArgument => error
      raise_missing_argument(error.args[0])
    rescue OptionParser::InvalidOption => error
      raise Fig::Command::OptionError.new(
        "Unknown option #{error.args[0]}.\n\n#{USAGE}"
      )
    rescue OptionParser::ParseError => error
      raise Fig::Command::OptionError.new(error.to_s)
    end

    if not exit_code.nil?
      return
    end

    if argv.size > 1
      $stderr.puts %q<Extra arguments. Should only have a package/version after all other options. Had "> + argv.join(%q<", ">) + %q<" left over.>
      @exit_code = 1
      return
    end

    if not @base_action
      set_base_action(Fig::Command::Action::RunCommandStatement)
    end
    set_up_sub_actions()
    derive_primary_descriptor(argv.first)

    actions().each {|action| action.configure(self)}

    return
  end

  def raise_missing_argument(option)
    raise Fig::Command::OptionError.new(
      "Please provide a value for #{option}."
    )
  end

  def raise_invalid_argument(option, value)
    # *sigh* OptionParser does not raise MissingArgument for the case of an
    # option with a required value being followed by another option.  It
    # assigns the next option as the value instead.  E.g. for
    #
    #    fig --set --get FOO
    #
    # it assigns "--get" as the value of the "--set" option.
    switch_strings =
      (@switches.collect {|switch| [switch.short, switch.long]}).flatten
    if switch_strings.any? {|string| string == value}
      raise_missing_argument(option)
    end

    description = ARGUMENT_DESCRIPTION[option]
    if description.nil?
      description = ''
    else
      description = ' ' + description
    end

    raise Fig::Command::OptionError.new(
      %Q<Invalid value for #{option}: "#{value}".#{description}>
    )
  end

  def new_parser
    return OptionParser.new do |parser|
      set_up_queries(parser)
      set_up_commands(parser)
      set_up_package_configuration_source(parser)
      set_up_environment_statements(parser)
      set_up_package_contents_statements(parser)
      set_up_remote_repository_access(parser)
      set_up_program_configuration(parser)
    end
  end

  def set_up_queries(parser)
    parser.banner = "#{USAGE}\n"
    @switches << parser.define_tail(
      '-?', '-h','--help','display this help text'
    ) do
      set_base_action(Fig::Command::Action::Help)
      @options[:help] = true
    end

    @switches << parser.define_tail('-v', '--version', 'print Fig version') do
      set_base_action(Fig::Command::Action::Version)
      @options[:version] = true
    end

    @switches << parser.define(
      '-g',
      '--get VARIABLE',
      STARTS_WITH_NON_HYPHEN,
      'print value of environment variable VARIABLE'
    ) do |get|
      set_base_action(Fig::Command::Action::Get)
      @options[:get] = get
    end

    set_up_listings(parser)

    return
  end

  def set_up_listings(parser)
    option_mapping = {
      :local_packages => [
        ['--list-local', '--list', 'list packages in $FIG_HOME'],
        Fig::Command::Action::ListLocal
      ],

      :configs => [
        ['--list-configs', 'list configurations'],
        Fig::Command::Action::ListConfigs
      ],

      :dependencies => [
        ['--list-dependencies', 'list package dependencies, recursively'],
        Fig::Command::Action::ListDependencies
      ],

      :variables => [
        [
          '--list-variables',
          'list all variables defined/used by package and its dependencies'
        ],
        Fig::Command::Action::ListVariables
      ],

      :remote_packages => [
        ['--list-remote', 'list packages in remote repo'],
        Fig::Command::Action::ListRemote
      ],
    }

    option_mapping.each_pair do
      | type, specification_action_class |

      specification, action_class = *specification_action_class
      @switches << parser.define(*specification) do
        set_base_action(action_class)
        @options[:listing] = type
      end
    end

    @switches << parser.define(
      '--list-tree', 'for listings, output a tree instead of a list'
    ) do
      @options[:list_tree] = true
    end

    @switches << parser.define(
      '--list-all-configs',
      'for listings, follow all configurations of the base package'
    ) do
      @options[:list_all_configs] = true
    end

    return
  end

  def set_up_commands(parser)
    @switches << parser.define('--clean', 'remove package from $FIG_HOME') do
      set_base_action(Fig::Command::Action::Clean)
      @options[:clean] = true
    end

    @switches << parser.define(
      '--publish', 'install package in $FIG_HOME and in remote repo'
    ) do |publish|
      set_base_action(Fig::Command::Action::Publish)
      @options[:publish] = true
    end

    @switches << parser.define(
      '--publish-local', 'install package only in $FIG_HOME'
    ) do |publish_local|
      set_base_action(Fig::Command::Action::PublishLocal)
      @options[:publish_local] = true
    end

    return
  end

  FILE_OPTION_VALUE_PATTERN =
    %r<
      \A
      (?:
          -         # Solely a hyphen, to allow for stdin
        | [^-] .*   # or anything not starting with a hyphen.
      )
      \z
    >x

  def set_up_package_configuration_source(parser)
    @switches << parser.define(
      '-c',
      '--config CONFIG',
      STARTS_WITH_NON_HYPHEN,
      %q<apply configuration CONFIG, default is "default">
    ) do |config|
      @options[:config] = config
    end

    @options[:package_definition_file] = nil
    @switches << parser.define(
      '--file FILE',
      FILE_OPTION_VALUE_PATTERN,
      %q<read Fig file FILE. Use '-' for stdin. See also --no-file>
    ) do |path|
      @options[:package_definition_file] = path
    end

    @switches << parser.define(
      '--no-file', 'ignore package.fig file in current directory'
    ) do |path|
      @options[:package_definition_file] = :none
    end

    return
  end

  def set_up_environment_statements(parser)
    @options[:environment_statements] = []
    @switches << parser.define(
      '-p',
      '--append VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'append (actually, prepend) VALUE to PATH-like environment variable VARIABLE'
    ) do |name_value|
      @options[:environment_statements] <<
        new_variable_statement('--append', name_value, Fig::Statement::Path)
    end

    @switches << parser.define(
      '-s',
      '--set VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'set environment variable VARIABLE to VALUE'
    ) do |name_value|
      @options[:environment_statements] <<
        new_variable_statement('--set', name_value, Fig::Statement::Set)
    end

    @switches << parser.define(
      '-i',
      '--include DESCRIPTOR',
      STARTS_WITH_NON_HYPHEN,
      'include package/version:config specified in DESCRIPTOR in environment'
    ) do |descriptor_string|
      statement =
        Fig::Statement::Include.new(
          nil,
          '--include option',
          Fig::Statement::Include.parse_descriptor(
            descriptor_string,
            :validation_context => ' given in a --include option'
          ),
          nil
        )

      # We've never allowed versionless includes from the command-line. Hooray!
      statement.complain_if_version_missing()

      @options[:environment_statements] << statement
    end

    @switches << parser.define(
      '--override DESCRIPTOR',
      STARTS_WITH_NON_HYPHEN,
      'dictate version of package as specified in DESCRIPTOR'
    ) do |descriptor_string|
      descriptor =
        Fig::Statement::Override.parse_descriptor(
          descriptor_string,
          :validation_context => ' given in a --override option'
        )
      statement =
        Fig::Statement::Override.new(
          nil, '--override option', descriptor.name, descriptor.version
        )

      @options[:environment_statements] << statement
    end

    return
  end

  def set_up_package_contents_statements(parser)
    @options[:archives] = []
    @switches << parser.define(
      '--archive PATH',
      STARTS_WITH_NON_HYPHEN,
      'include PATH archive in package (when using --publish)'
    ) do |path|
      @options[:archives] <<
        Fig::Statement::Archive.new(nil, '--archive option', path)
    end

    @options[:resources] =[]
    @switches << parser.define(
      '--resource PATH',
      STARTS_WITH_NON_HYPHEN,
      'include PATH resource in package (when using --publish)'
    ) do |path|
      @options[:resources] <<
        Fig::Statement::Resource.new(nil, '--resource option', path)
    end

    return
  end

  def set_up_remote_repository_access(parser)
    @switches << parser.define(
      '-u',
      '--update',
      'check remote repo for updates and download to $FIG_HOME as necessary'
    ) do
      set_update_action(Fig::Command::Action::Update)
      @options[:update] = true
    end

    @switches << parser.define(
      '-m',
      '--update-if-missing',
      'check remote repo for updates only if package missing from $FIG_HOME'
    ) do
      set_update_action(Fig::Command::Action::UpdateIfMissing)
      @options[:update_if_missing] = true
    end

    @switches << parser.define(
      '-l', '--login', 'login to remote repo as a non-anonymous user'
    ) do
      @options[:login] = true
    end

    @options[:force] = nil
    @switches << parser.define(
      '--force',
      'force-overwrite existing version of a package to the remote repo'
    ) do |force|
      @options[:force] = force
    end

    return
  end

  def set_up_program_configuration(parser)
    @switches << parser.define(
      '--figrc PATH',
      STARTS_WITH_NON_HYPHEN,
      'add PATH to configuration used for Fig'
    ) do |path|
      @options[:figrc] = path
    end

    @switches << parser.define('--no-figrc', 'ignore ~/.figrc') { @options[:no_figrc] = true }

    @switches << parser.define(
      '--log-config PATH',
      STARTS_WITH_NON_HYPHEN,
      'use PATH file as configuration for Log4r'
    ) do |path|
      @options[:log_config] = path
    end

    level_list = LOG_LEVELS.join(', ')
    @switches << parser.define(
      '--log-level LEVEL',
      LOG_LEVELS,
      LOG_ALIASES,
      'set logging level to LEVEL',
      "  (#{level_list})"
    ) do |log_level|
      @options[:log_level] = log_level
    end

    @switches << parser.define(
      '--suppress-warning-include-statement-missing-version',
      %q<don't complain about "include package" without a version>
    ) do
      @options[:suppress_warning_include_statement_missing_version] = true
    end

    return
  end

  def set_base_action(action_class)
    action = action_class.new
    # Help overrides anything.
    if action_class == Fig::Command::Action::Help
      @base_action = action
      return
    end

    return if @base_action && @base_action == Fig::Command::Action::Help

    if @base_action
      raise Fig::Command::OptionError.new(
        "Cannot specify both #{@base_action.options[0]} and #{action.options[0]}."
      )
    end

    @base_action = action

    return
  end

  def set_update_action(update_action_class)
    update_action = update_action_class.new
    if @update_action
      raise Fig::Command::OptionError.new(
        "Cannot specify both #{@update_action.options[0]} and #{update_action.options[0]}."
      )
    end

    @update_action = update_action
  end

  def new_variable_statement(option, name_value, statement_class)
    variable, value = statement_class.parse_name_value(name_value) {
      raise_invalid_argument(option, name_value)
    }

    return statement_class.new(nil, "#{option} option", variable, value)
  end

  def set_up_sub_actions()
    if @base_action.sub_action?
      # This is a cheat because the only things with sub-actions at present are
      # --list-dependencies and --list-variables.  This will need to be
      # refactored if we get further sub-action actions.
      sub_action_name = :Default
      if list_tree?
        sub_action_name = list_all_configs? ? :TreeAllConfigs : :Tree
      elsif list_all_configs?
        sub_action_name = :AllConfigs
      end

      @base_action.sub_action =
        @base_action.class.const_get(sub_action_name).new
    end
  end

  # This will be the base package, unless we're publishing (in which case it's
  # the name to publish to.
  def derive_primary_descriptor(raw_string)
    return if raw_string.nil?

    @descriptor = Fig::PackageDescriptor.parse(
      raw_string,
      :name    => :required,
      :version => :required,
      :validation_context => ' specified on command line'
    )

    if @descriptor.config && config()
      $stderr.puts \
        %Q<Cannot specify both --config and a config in the descriptor "#{raw_string}".>
      @exit_code = 1
    end

    return
  end
end
