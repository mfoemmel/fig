require 'optparse'

require 'fig/command/optionerror'
require 'fig/package'
require 'fig/packagedescriptor'
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
          terminating_option = arg
          @shell_command = argv[(i+1)..-1]
        when '--command-extra-args'
          terminating_option = arg
          @command_extra_argv = argv[(i+1)..-1]
      end

      if terminating_option
        argv.slice!(i..-1)
        break
      end
    end

    return
  end

  # This needs to be public for efficient use of custom command.rb wrappers.
  def help()
    puts @help_message
    puts <<-'END_MESSAGE'
        --                           end of Fig options; anything after this is used as a command to run
        --command-extra-args         end of Fig options; anything after this is appended to the end of a
                                     "command" statement in a "config" block.

    END_MESSAGE

    return 0
  end

  private

  # Note that OptionParser insist that the regex match the entire value, not
  # just matches the regex in general.  In effect, OptionParser is wrapping the
  # regex with "\A" and "\z".
  STARTS_WITH_NON_HYPHEN = %r< \A [^-] .* >x

  ARGUMENT_DESCRIPTION = {
    '--set'    =>
      %q<The value must look like "NAME=VALUE", though VALUE can be empty.>,
    '--append' =>
      %q[The value must look like "NAME=VALUE". VALUE cannot contain any of ";:<>|", double quotes, or whitespace.],
  }

  def process_command_line(argv)
    argv = argv.clone
    strip_shell_command(argv)

    @options = {}

    @options[:home] = ENV['FIG_HOME'] || File.expand_path('~/.fighome')

    parser = new_parser()
    @help_message = parser.help

    begin
      parser.parse!(argv)
    rescue OptionParser::InvalidArgument => error
      raise_invalid_argument(error.args[0], error.args[1])
    rescue OptionParser::MissingArgument => error
      raise Fig::Command::OptionError.new(
        "Please provide a value for #{error.args[0]}."
      )
    end

    if not exit_code.nil?
      return
    end

    if argv.size > 1
      $stderr.puts %q<Extra arguments. Should only have a package/version after all other options. Had "> + argv.join(%q<", ">) + %q<" left over.>
      @exit_code = 1
      return
    end

    derive_descriptor(argv.first)

    return
  end

  def raise_invalid_argument(option, value)
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
    parser.banner = USAGE
    parser.on_tail('-?', '-h','--help','display this help text') do
      @options[:help] = true
    end

    parser.on_tail('-v', '--version', 'print Fig version') do
      @options[:version] = true
    end

    parser.on(
      '-g',
      '--get VARIABLE',
      STARTS_WITH_NON_HYPHEN,
      'print value of environment variable VARIABLE'
    ) do |get|
      @options[:get] = get
    end

    set_up_listings(parser)

    return
  end

  def set_up_listings(parser)
    option_mapping = {
      :local_packages =>
        [ '--list-local', '--list', 'list packages in $FIG_HOME' ],

      :configs =>
        ['--list-configs', 'list configurations'],

      :dependencies =>
        ['--list-dependencies', 'list package dependencies, recursively'],

      :variables =>
        [
          '--list-variables',
          'list all variables defined/used by package and its dependencies'
        ],

      :remote_packages =>
        ['--list-remote', 'list packages in remote repo']
    }

    option_mapping.each_pair do
      | type, specification |

      parser.on(*specification) do
        if @options[:listing]
          options_string =
            (
              option_mapping.values.collect {|specification| specification[0]}
            ).join(', ')

          $stderr.puts "Can only specify one of #{options_string}."
          @exit_code = 1
        else
          @options[:listing] = type
        end
      end
    end

    parser.on('--list-tree', 'for listings, output a tree instead of a list') do
      @options[:list_tree] = true
    end

    parser.on('--list-all-configs', 'for listings, follow all configurations of the base package') do
      @options[:list_all_configs] = true
    end

    return
  end

  def set_up_commands(parser)
    parser.on('--clean', 'remove package from $FIG_HOME') do
      @options[:clean] = true
    end

    parser.on(
      '--publish', 'install package in $FIG_HOME and in remote repo'
    ) do |publish|
      @options[:publish] = true
    end

    parser.on(
      '--publish-local', 'install package only in $FIG_HOME'
    ) do |publish_local|
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
    parser.on(
      '-c',
      '--config CONFIG',
      STARTS_WITH_NON_HYPHEN,
      %q<apply configuration CONFIG, default is "default">
    ) do |config|
      @options[:config] = config
    end

    @options[:package_definition_file] = nil
    parser.on(
      '--file FILE',
      FILE_OPTION_VALUE_PATTERN,
      %q<read Fig file FILE. Use '-' for stdin. See also --no-file>
    ) do |path|
      @options[:package_definition_file] = path
    end

    parser.on(
      '--no-file', 'ignore package.fig file in current directory'
    ) do |path|
      @options[:package_definition_file] = :none
    end

    return
  end

  def set_up_environment_statements(parser)
    @options[:environment_statements] = []
    parser.on(
      '-p',
      '--append VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'append (actually, prepend) VALUE to PATH-like environment variable VARIABLE'
    ) do |name_value|
      @options[:environment_statements] <<
        new_variable_statement('--append', name_value, Fig::Statement::Path)
    end

    parser.on(
      '-s',
      '--set VARIABLE=VALUE',
      STARTS_WITH_NON_HYPHEN,
      'set environment variable VARIABLE to VALUE'
    ) do |name_value|
      @options[:environment_statements] <<
        new_variable_statement('--set', name_value, Fig::Statement::Set)
    end

    parser.on(
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

    parser.on(
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
    parser.on(
      '--archive PATH',
      STARTS_WITH_NON_HYPHEN,
      'include PATH archive in package (when using --publish)'
    ) do |path|
      @options[:archives] <<
        Fig::Statement::Archive.new(nil, '--archive option', path)
    end

    @options[:resources] =[]
    parser.on(
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
    parser.on(
      '-u',
      '--update',
      'check remote repo for updates and download to $FIG_HOME as necessary'
    ) do
      @options[:update] = true
    end

    parser.on(
      '-m',
      '--update-if-missing',
      'check remote repo for updates only if package missing from $FIG_HOME'
    ) do
      @options[:update_if_missing] = true
    end

    parser.on(
      '-l', '--login', 'login to remote repo as a non-anonymous user'
    ) do
      @options[:login] = true
    end

    @options[:force] = nil
    parser.on(
      '--force',
      'force-overwrite existing version of a package to the remote repo'
    ) do |force|
      @options[:force] = force
    end

    return
  end

  def set_up_program_configuration(parser)
    parser.on(
      '--figrc PATH',
      STARTS_WITH_NON_HYPHEN,
      'add PATH to configuration used for Fig'
    ) do |path|
      @options[:figrc] = path
    end

    parser.on('--no-figrc', 'ignore ~/.figrc') { @options[:no_figrc] = true }

    parser.on(
      '--log-config PATH',
      STARTS_WITH_NON_HYPHEN,
      'use PATH file as configuration for Log4r'
    ) do |path|
      @options[:log_config] = path
    end

    level_list = LOG_LEVELS.join(', ')
    parser.on(
      '--log-level LEVEL',
      LOG_LEVELS,
      LOG_ALIASES,
      'set logging level to LEVEL',
      "  (#{level_list})"
    ) do |log_level|
      @options[:log_level] = log_level
    end

    parser.on(
      '--suppress-warning-include-statement-missing-version',
      %q<don't complain about "include package" without a version>
    ) do
      @options[:suppress_warning_include_statement_missing_version] = true
    end

    return
  end

  def new_variable_statement(option, name_value, statement_class)
    variable, value = name_value.split("=")

    if variable !~ statement_class.const_get(:NAME_REGEX)
      raise_invalid_argument(option, name_value)
    end

    value = '' if value.nil?
    if value !~ statement_class.const_get(:VALUE_REGEX)
      raise_invalid_argument(option, name_value)
    end

    return statement_class.new(
      nil, "#{option} option", variable, value.nil? ? '' : value
    )
  end

  def derive_descriptor(raw_string)
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
