# coding: utf-8

require 'fig/command/action/clean'
require 'fig/command/action/dump_package_definition_for_command_line'
require 'fig/command/action/dump_package_definition_parsed'
require 'fig/command/action/dump_package_definition_text'
require 'fig/command/action/get'
require 'fig/command/action/help'
require 'fig/command/action/help_long'
require 'fig/command/action/list_configs'
require 'fig/command/action/list_dependencies'
require 'fig/command/action/list_dependencies/all_configs'
require 'fig/command/action/list_dependencies/default'
require 'fig/command/action/list_dependencies/graphviz'
require 'fig/command/action/list_dependencies/graphviz_all_configs'
require 'fig/command/action/list_dependencies/json'
require 'fig/command/action/list_dependencies/json_all_configs'
require 'fig/command/action/list_dependencies/tree'
require 'fig/command/action/list_dependencies/tree_all_configs'
require 'fig/command/action/list_dependencies/yaml'
require 'fig/command/action/list_dependencies/yaml_all_configs'
require 'fig/command/action/list_local'
require 'fig/command/action/list_remote'
require 'fig/command/action/list_variables'
require 'fig/command/action/list_variables/all_configs'
require 'fig/command/action/list_variables/default'
require 'fig/command/action/list_variables/graphviz'
require 'fig/command/action/list_variables/graphviz_all_configs'
require 'fig/command/action/list_variables/json'
require 'fig/command/action/list_variables/json_all_configs'
require 'fig/command/action/list_variables/tree'
require 'fig/command/action/list_variables/tree_all_configs'
require 'fig/command/action/list_variables/yaml'
require 'fig/command/action/list_variables/yaml_all_configs'
require 'fig/command/action/options'
require 'fig/command/action/publish'
require 'fig/command/action/publish_local'
require 'fig/command/action/run_command_line'
require 'fig/command/action/run_command_statement'
require 'fig/command/action/source_package'
require 'fig/command/action/update'
require 'fig/command/action/update_if_missing'
require 'fig/command/action/version'
require 'fig/command/action/version_plain'
require 'fig/command/option_error'
require 'fig/command/options/parser'
require 'fig/package_descriptor'
require 'fig/statement/archive'
require 'fig/statement/command'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/set'

module Fig; end
class Fig::Command; end

# Command-line processing.
class Fig::Command::Options
  attr_reader   :asset_statements
  attr_reader   :command_extra_argv
  attr_reader   :config
  attr_reader   :descriptor
  attr_reader   :environment_statements
  attr_reader   :exit_code
  attr_reader   :figrc
  attr_reader   :file_to_find_package_for
  attr_reader   :home
  attr_reader   :log_config
  attr_reader   :log_to_stdout
  attr_reader   :log_level
  attr_reader   :package_definition_file
  attr_reader   :parser
  attr_reader   :publish_comment
  attr_reader   :publish_comment_path
  attr_reader   :shell_command
  attr_reader   :suppress_cleanup_of_retrieves
  attr_reader   :suppress_includes
  attr_reader   :suppress_retrieves
  attr_reader   :update_lock_response
  attr_reader   :variable_to_get
  attr_accessor :version_message
  attr_accessor :version_plain

  def initialize()
    @home   = ENV['FIG_HOME'] || File.expand_path('~/.fighome')
    @parser = Fig::Command::Options::Parser.new()
  end

  def process_command_line(argv)
    argv = argv.clone
    strip_shell_command(argv)

    set_up_parser()

    @parser.parse!(argv)

    if not exit_code.nil?
      return
    end

    if argv.size > 1
      $stderr.puts %q<Extra arguments. Should only have a package/version after all other options. Had "> + argv.join(%q<", ">) + %q<" left over.>
      @exit_code = 1
      return
    end

    derive_primary_descriptor(argv.first)
    if not @base_action and @descriptor
      set_base_action(Fig::Command::Action::RunCommandStatement)
    end
    set_up_sub_actions()

    validate

    actions().each {|action| action.configure(self)}

    return
  end

  def actions()
    actions = []

    # Update has got to come first so that the Repository knows what's going
    # on.
    if @update_action
      actions << @update_action
    end
    if @base_action
      actions << @base_action
    end

    return actions
  end

  def force?()
    return @force
  end

  def suppress_vcs_comments_in_published_packages?()
    return @suppress_vcs_comments_in_published_packages
  end

  def short_help_message()
    return @parser.short_help
  end

  def full_help_message()
    return @parser.full_help + EXTRA_OPTIONS_DESCRIPTION
  end

  def options_message()
    return @parser.options_message + EXTRA_OPTIONS_DESCRIPTION
  end

  def login?()
    return @login
  end

  def no_figrc?()
    return @no_figrc
  end

  def no_remote_figrc?()
    return @no_remote_figrc
  end

  def suppress_warning_include_statement_missing_version?()
    return @suppress_warning_include_statement_missing_version
  end

  def suppress_warning_unused_retrieve?()
    return @suppress_warning_unused_retrieve
  end

  private

  EXTRA_OPTIONS_DESCRIPTION = <<-'END_DESCRIPTION'

Running commands:
        --                           end of Fig options; anything after this is used as a command to run
        --command-extra-args         end of Fig options; anything after this is appended to the end of a
                                     "command" statement in a "config" block.

  END_DESCRIPTION

  # Note that OptionParser insists that the regex match the entire value, not
  # just matches the regex in general.  In effect, OptionParser is wrapping the
  # regex with "\A" and "\z".
  STARTS_WITH_NON_HYPHEN = %r< \A [^-] .* >xm

  def list_all_configs?()
    return @list_all_configs
  end

  def list_tree?()
    return @list_tree
  end

  def json?()
    return @json
  end

  def yaml?()
    return @yaml
  end

  def graphviz?()
    return @graphviz
  end

  def strip_shell_command(argv)
    argv.each_with_index do |arg, i|
      case arg
        when '--'
          set_base_action(Fig::Command::Action::RunCommandLine)
          @shell_command = tokenize_command_arguments '--', argv[(i+1)..-1]

          if @shell_command.empty?
            raise Fig::Command::OptionError.new(
              %q<The "--" option was used, but no command was specified.>
            )
          end
        when '--command-extra-args'
          set_base_action(Fig::Command::Action::RunCommandStatement)
          @command_extra_argv =
            tokenize_command_arguments '--command-extra-args', argv[(i+1)..-1]
      end

      if @base_action
        argv.slice!(i..-1)
        break
      end
    end

    return
  end

  def set_up_parser()
    set_up_package_definition()
    set_up_remote_repository_access()
    set_up_commands()
    set_up_environment_statements()
    set_up_asset_statements()
    set_up_queries()
    set_up_program_configuration()
    set_up_help()

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

  def set_up_package_definition()
    @parser.separator 'Package definition:'

    @parser.on(
      '-c',
      '--config CONFIG',
      STARTS_WITH_NON_HYPHEN,
      %q<apply configuration CONFIG, default is "default">
    ) do |config|
      @config = config
    end

    @parser.on(
      '--file FILE',
      FILE_OPTION_VALUE_PATTERN,
      %q<read package definition FILE. Use '-' for stdin. See also --no-file>
    ) do |path|
      set_package_definition_file(path)
    end

    @parser.on(
      '--no-file', 'ignore package.fig/application.fig file in current directory'
    ) do
      set_package_definition_file(:none)
    end

    @parser.on(
      '--suppress-all-includes', %q<don't process include statements>,
    ) do
      set_suppress_includes(:all)
    end

    @parser.on(
      '--suppress-cross-package-includes',
      %q<don't process includes of configs from other packages>,
    ) do
      set_suppress_includes(:cross_package)
    end

    return
  end

  def set_up_remote_repository_access()
    @parser.separator ''
    @parser.separator 'Remote repository access:'

    @parser.on(
      '-u',
      '--update',
      'check remote repo for updates, download to $FIG_HOME and process retrieves'
    ) do
      set_update_action(Fig::Command::Action::Update)
    end

    @parser.on(
      '-m',
      '--update-if-missing',
      'check remote repo for updates only if package missing from $FIG_HOME'
    ) do
      set_update_action(Fig::Command::Action::UpdateIfMissing)
    end

    @parser.on(
      '-R', '--suppress-retrieves',
      %q<don't process retrieves, even if they would otherwise be active>,
    ) do
      @suppress_retrieves = true
    end

    @parser.on(
      '--suppress-cleanup-of-retrieves',
      %q<don't delete files from unreferenced retrieves>,
    ) do
      @suppress_cleanup_of_retrieves = true
    end

    @parser.on(
      '-l', '--login', 'login to FTP repo as a non-anonymous user'
    ) do
      @login = true
    end

    return
  end

  def set_up_commands()
    @parser.separator ''
    @parser.separator 'Commands:'

    @parser.on(
      '--publish', 'install package in $FIG_HOME and in remote repo'
    ) do |publish|
      set_base_action(Fig::Command::Action::Publish)
    end

    @parser.on(
      '--publish-local', 'install package only in $FIG_HOME'
    ) do |publish_local|
      set_base_action(Fig::Command::Action::PublishLocal)
    end

    @parser.on(
      '--publish-comment COMMENT',
      STARTS_WITH_NON_HYPHEN,
      'comment to include in published package'
    ) do |comment|
      @publish_comment = comment
    end

    @parser.on(
      '--publish-comment-file PATH',
      STARTS_WITH_NON_HYPHEN,
      'file to include as a comment in published package'
    ) do |path|
      @publish_comment_path = path
    end

    @force = nil
    @parser.on(
      '--force',
      'force-overwrite existing version of a package to the remote repo'
    ) do |force|
      @force = force
    end

    @parser.on(
      '--suppress-vcs-comments-in-published-packages',
      %q<don't attempt to identify version control information when publishing>
    ) do |suppress|
      @suppress_vcs_comments_in_published_packages = suppress
    end

    @parser.on('--clean', 'remove package from $FIG_HOME') do
      set_base_action(Fig::Command::Action::Clean)
    end

    @parser.on(
      '--run-command-statement',
      'run the command in package definition file (i.e. with no package descriptor specified)'
    ) do
      set_base_action(Fig::Command::Action::RunCommandStatement)
    end

    return
  end

  def set_up_environment_statements()
    @parser.separator ''
    @parser.separator 'Environment variable statement equivalents:'

    @environment_statements = []
    @parser.on(
      '-p',
      '--append VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'append (actually, prepend) VALUE to PATH-like environment variable VARIABLE'
    ) do |name_value|
      @environment_statements <<
        new_variable_statement('--append', name_value, Fig::Statement::Path)
    end
    @parser.add_argument_description(
      %w<-p --append>, %q<The value of this option must look like "NAME=VALUE".>
    )
    @parser.on(
      '--add VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'prepend VALUE to PATH-like environment variable VARIABLE (synonym for --append)'
    ) do |name_value|
      @environment_statements <<
        new_variable_statement('--add', name_value, Fig::Statement::Path)
    end
    @parser.add_argument_description(
      %w<--add>, %q<The value of this option must look like "NAME=VALUE".>
    )

    @parser.on(
      '-s',
      '--set VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'set environment variable VARIABLE to VALUE'
    ) do |name_value|
      @environment_statements <<
        new_variable_statement('--set', name_value, Fig::Statement::Set)
    end
    @parser.add_argument_description(
      %w<-s --set>, %q<The value of this option must look like "NAME=VALUE".>
    )

    @parser.separator ''
    @parser.separator 'Package includes and overrides:'

    @parser.on(
      '-i',
      '--include DESCRIPTOR',
      STARTS_WITH_NON_HYPHEN,
      'include package/version:config specified in DESCRIPTOR in environment'
    ) do |descriptor_string|
      statement = Fig::Statement::Include.new(
        nil,
        '--include option',
        Fig::Statement::Include.parse_descriptor(
          descriptor_string,
          :validation_context => ' given in a --include option'
        ),
        nil,
        nil
      )

      # We've never allowed versionless includes from the command-line. Hooray!
      statement.complain_if_version_missing()

      @environment_statements << statement
    end

    @parser.on(
      '--include-file PATH:CONFIG',
      STARTS_WITH_NON_HYPHEN,
      'include package-definition-in-file:config in environment (incompatible with --publish)'
    ) do |path_with_config|
      path, config_name =
        Fig::Statement::IncludeFile.parse_path_with_config(path_with_config) {
          |message|

          @parser.raise_invalid_argument(
            '--include-file', path_with_config, message
          )
        }
      statement = Fig::Statement::IncludeFile.new(
        nil, '--include-file option', path, config_name, nil,
      )

      @environment_statements << statement
    end

    @parser.on(
      '--override DESCRIPTOR',
      STARTS_WITH_NON_HYPHEN,
      'dictate version of package as specified in DESCRIPTOR'
    ) do |descriptor_string|
      descriptor =
        Fig::Statement::Override.parse_descriptor(
          descriptor_string,
          :validation_context => ' given in a --override option'
        )
      statement = Fig::Statement::Override.new(
        nil, '--override option', descriptor.name, descriptor.version
      )

      @environment_statements << statement
    end

    return
  end

  def set_up_asset_statements()
    @parser.separator ''
    @parser.separator 'Asset statement equivalents:'

    @asset_statements = []
    @parser.on(
      '--archive PATH',
      STARTS_WITH_NON_HYPHEN,
      'include PATH archive in package (when using --publish)'
    ) do |path|
      @asset_statements <<
        new_asset_statement('--archive', path, Fig::Statement::Archive)
    end

    @parser.on(
      '--resource PATH',
      STARTS_WITH_NON_HYPHEN,
      'include PATH resource in package (when using --publish)'
    ) do |path|
      @asset_statements <<
        new_asset_statement('--resource', path, Fig::Statement::Resource)
    end

    return
  end

  def set_up_queries()
    @parser.separator ''
    @parser.separator 'Querying:'

    @parser.on(
      '-g',
      '--get VARIABLE',
      STARTS_WITH_NON_HYPHEN,
      'print value of environment variable VARIABLE'
    ) do |variable_to_get|
      set_base_action(Fig::Command::Action::Get)
      @variable_to_get = variable_to_get
    end

    @parser.on(
      '--source-package FILE',
      STARTS_WITH_NON_HYPHEN,
      'print package FILE was retrieved from'
    ) do |file_to_find_package_for|
      set_base_action(Fig::Command::Action::SourcePackage)
      @file_to_find_package_for = file_to_find_package_for
    end

    @parser.on(
      '-T', '--dump-package-definition-text',
      'emit the unparsed definition of the base package, if there is one'
    ) do
      set_base_action(Fig::Command::Action::DumpPackageDefinitionText)
    end
    @parser.on(
      '--dump-package-definition-parsed',
      'emit the parsed definition of the base package'
    ) do
      set_base_action(Fig::Command::Action::DumpPackageDefinitionParsed)
    end
    @parser.on(
      '--dump-package-definition-for-command-line',
      'emit the synthetic package for the other options (--set/--archive/etc.)'
    ) do
      set_base_action(Fig::Command::Action::DumpPackageDefinitionForCommandLine)
    end

    set_up_listings()

    return
  end

  def set_up_listings()
    @parser.separator ''
    @parser.separator 'Querying repository contents:'

    option_mapping = {
      :local_packages => [
        ['--list-local', '--list', 'list packages in $FIG_HOME'],
        Fig::Command::Action::ListLocal
      ],

      :remote_packages => [
        ['--list-remote', 'list packages in remote repository'],
        Fig::Command::Action::ListRemote
      ],
    }

    option_mapping.each_pair do
      | type, specification_action_class |

      specification, action_class = *specification_action_class
      @parser.on(*specification) do
        set_base_action(action_class)
      end
    end

    @parser.separator ''
    @parser.separator 'Querying package data:'

    option_mapping = {
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
    }

    option_mapping.each_pair do
      | type, specification_action_class |

      specification, action_class = *specification_action_class
      @parser.on(*specification) do
        set_base_action(action_class)
      end
    end

    @parser.on(
      '--list-tree', 'for listings, output a tree instead of a list'
    ) do
      @list_tree = true
    end

    @parser.on(
      '--json', 'for listings, output JSON (http://json.org)'
    ) do
      @json = true
    end

    @parser.on(
      '--yaml', 'for listings, output YAML (http://yaml.org)'
    ) do
      @yaml = true
    end

    @parser.on(
      '--graphviz',
      'for listings, output DOT (http://graphviz.org/content/dot-language)'
    ) do
      @graphviz = true
    end

    @parser.on(
      '--list-all-configs',
      'for listings, follow all configurations of the base package'
    ) do
      @list_all_configs = true
    end

    return
  end

  LOG_LEVELS = %w< off fatal error warn info debug all >
  LOG_ALIASES = { 'warning' => 'warn' }

  def set_up_program_configuration()
    @parser.separator ''
    @parser.separator 'Fig configuration:'

    @parser.on(
      '--figrc PATH',
      STARTS_WITH_NON_HYPHEN,
      'add PATH to configuration used for Fig'
    ) do |path|
      @figrc = path
    end

    @parser.on('--no-figrc', 'ignore ~/.figrc') { @no_figrc = true }
    @parser.on('--no-remote-figrc', 'ignore $FIG_REMOTE_URL/_meta/figrc') {
      @no_remote_figrc = true
    }

    @parser.on(
      '--log-config PATH',
      STARTS_WITH_NON_HYPHEN,
      'use PATH file as configuration for Log4r'
    ) do |path|
      @log_config = path
    end

    @parser.on(
      '--log-to-stdout', 'write log output to stdout instead of stderr',
    ) do
      @log_to_stdout = true
    end

    level_list = LOG_LEVELS.join(', ')
    @parser.on(
      '--log-level LEVEL',
      LOG_LEVELS,
      LOG_ALIASES,
      'set logging level to LEVEL',
      "  (#{level_list})"
    ) do |log_level|
      @log_level = log_level
    end

    @update_lock_response = nil # Nil means wait, but warn.
    update_lock_responses = [:wait, :fail, :ignore]
    response_list = update_lock_responses.join(', ')
    @parser.on(
      '--update-lock-response TYPE',
      update_lock_responses,
      'what to do when update lock already exists',
      "  (#{response_list}, default is wait)"
    ) do |response|
      @update_lock_response = response
    end

    @parser.on(
      '--suppress-warning-include-statement-missing-version',
      %q<don't complain about an include statement without a version>
    ) do
      @suppress_warning_include_statement_missing_version = true
    end

    @parser.on(
      '--suppress-warning-unused-retrieve',
      %q<don't complain about a retrieve statement that isn't used>
    ) do
      @suppress_warning_unused_retrieve = true
    end

    return
  end

  def set_up_help()
    @parser.separator ''
    @parser.separator 'Help:'

    @parser.on(
      '-?', '-h', '--help', 'display short usage summary'
    ) do
      set_base_action(Fig::Command::Action::Help)
    end
    @parser.on(
      '--help-long', 'display full usage'
    ) do
      set_base_action(Fig::Command::Action::HelpLong)
    end
    @parser.on(
      '--options', 'just list Fig options'
    ) do
      set_base_action(Fig::Command::Action::Options)
    end

    @parser.on('-v', '--version', 'print Fig version') do
      set_base_action(Fig::Command::Action::Version)
    end
    @parser.on(
      '--version-plain', 'print Fig version without embellishment (no newline)'
    ) do
      set_base_action(Fig::Command::Action::VersionPlain)
    end
  end

  def set_base_action(action_class)
    action = action_class.new
    # Help overrides anything.
    if action_class == Fig::Command::Action::Help
      @base_action = action
      return
    end

    if @base_action
      return if @base_action.class == Fig::Command::Action::Help
      return if @base_action.class == action_class
    end

    if @base_action
      raise Fig::Command::OptionError.new(
        "Cannot specify both #{@base_action.primary_option()} and #{action.primary_option()}."
      )
    end

    @base_action = action

    return
  end

  def set_package_definition_file(value)
    if @package_definition_file
      raise Fig::Command::OptionError.new(
        'Can only specify one --file/--no-file option.'
      )
    end

    @package_definition_file = value

    return
  end

  def set_suppress_includes(value)
    if @suppress_includes
      raise Fig::Command::OptionError.new(
        'Can only specify one --suppress-all-includes/--suppress-cross-package-includes option.'
      )
    end

    @suppress_includes = value

    return
  end

  def set_update_action(update_action_class)
    update_action = update_action_class.new
    if @update_action
      raise Fig::Command::OptionError.new(
        "Cannot specify both #{@update_action.primary_option()} and #{update_action.primary_option()}."
      )
    end

    @update_action = update_action

    return
  end

  def new_variable_statement(option, name_value, statement_class)
    variable, value = statement_class.parse_name_value(name_value) {
      |message|

      @parser.raise_invalid_argument(option, name_value, message)
    }

    return statement_class.new(nil, "#{option} option", variable, value)
  end

  def new_asset_statement(option, raw_path, statement_class)
    tokenized_path =
      statement_class.validate_and_process_escapes_in_location(raw_path) do
        |error_description|

        @parser.raise_invalid_argument(option, raw_path, error_description)
      end

    path = tokenized_path.to_expanded_string
    need_to_glob = ! tokenized_path.single_quoted?
    return statement_class.new(nil, "#{option} option", path, need_to_glob)
  end

  def validate()
    if suppress_includes
      # Not conceptually incompatible, just not implemented (would need to
      # handle in command/action/role/list_*)
      if list_tree?
        raise Fig::Command::OptionError.new(
          'Cannot use --suppress-all-includes/--suppress-cross-package-includes with --list-tree.'
        )
      elsif json?
        raise Fig::Command::OptionError.new(
          'Cannot use --suppress-all-includes/--suppress-cross-package-includes with --json.'
        )
      elsif yaml?
        raise Fig::Command::OptionError.new(
          'Cannot use --suppress-all-includes/--suppress-cross-package-includes with --yaml.'
        )
      elsif graphviz?
        raise Fig::Command::OptionError.new(
          'Cannot use --suppress-all-includes/--suppress-cross-package-includes with --graphviz.'
        )
      elsif list_all_configs?
        raise Fig::Command::OptionError.new(
          'Cannot use --suppress-all-includes/--suppress-cross-package-includes with --list-all-configs.'
        )
      elsif @base_action
        if @base_action.list_dependencies?
          raise Fig::Command::OptionError.new(
            %q<It doesn't make much sense to suppress dependencies when attempting to list them.>
          )
        elsif @base_action.publish?
          # Don't want to support broken publishes (though versionless includes
          # are pretty broken).
          raise Fig::Command::OptionError.new(
            'Cannot use --suppress-all-includes/--suppress-cross-package-includes when publishing.'
          )
        end
      end
    elsif list_tree?
      validate_list_option '--list-tree'
    elsif json?
      validate_list_option '--json'
    elsif yaml?
      validate_list_option '--yaml'
    elsif graphviz?
      validate_list_option '--graphviz'
    elsif list_all_configs?
      validate_list_option '--list-all-configs'
    end

    if list_tree?
      if graphviz?
        raise Fig::Command::OptionError.new(
          'Cannot use --list-tree and --graphviz at the same time.'
        )
      elsif json?
        raise Fig::Command::OptionError.new(
          'Cannot use --list-tree and --json at the same time.'
        )
      elsif yaml?
        raise Fig::Command::OptionError.new(
          'Cannot use --list-tree and --json at the same time.'
        )
      end
    end
    if graphviz?
      if json?
        raise Fig::Command::OptionError.new(
          'Cannot use --graphviz and --json at the same time.'
        )
      elsif yaml?
        raise Fig::Command::OptionError.new(
          'Cannot use --graphviz and --yaml at the same time.'
        )
      end
    end
    if json? and yaml?
      raise Fig::Command::OptionError.new(
        'Cannot use --json and --yaml at the same time.'
      )
    end

    if @publish_comment && (! @base_action || ! @base_action.publish?)
      raise Fig::Command::OptionError.new(
        'Cannot use --publish-comment when not publishing.'
      )
    end

    if @publish_comment_path && (! @base_action || ! @base_action.publish?)
      raise Fig::Command::OptionError.new(
        'Cannot use --publish-comment-file when not publishing.'
      )
    end

    if @log_to_stdout && @log_config
      raise Fig::Command::OptionError.new(
        'Cannot use --log-to-stdout and --log-config at the same time.'
      )
    end

    return
  end

  def validate_list_option(option)
    if (
          ! @base_action \
      ||  ! @base_action.list_dependencies? && ! @base_action.list_variables?
    )
      raise Fig::Command::OptionError.new(
        %Q<The #{option} option isn't useful without --list-dependencies/--list-variables.>
      )
    end

    return
  end

  def set_up_sub_actions()
    if @base_action and @base_action.sub_action?
      # This is a cheat because the only things with sub-actions at present are
      # --list-dependencies and --list-variables.  This will need to be
      # refactored if we get further sub-action actions.
      sub_action_name = :Default
      if list_tree?
        sub_action_name = list_all_configs? ? :TreeAllConfigs : :Tree
      elsif json?
        sub_action_name = list_all_configs? ? :JSONAllConfigs : :JSON
      elsif yaml?
        sub_action_name = list_all_configs? ? :YAMLAllConfigs : :YAML
      elsif graphviz?
        sub_action_name = list_all_configs? ? :GraphvizAllConfigs : :Graphviz
      elsif list_all_configs?
        sub_action_name = :AllConfigs
      end

      @base_action.sub_action =
        @base_action.class.const_get(sub_action_name).new
    end
  end

  # This will be the base package, unless we're publishing (in which case it's
  # the name to publish to).
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

  def tokenize_command_arguments(option, arguments)
    return arguments.map do
      |argument|

      Fig::Statement::Command.validate_and_process_escapes_in_argument(
        argument
      ) do
        |error_description|

        @parser.raise_invalid_argument(option, argument, error_description)
      end
    end
  end
end
