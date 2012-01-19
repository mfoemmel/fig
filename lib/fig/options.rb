require 'optparse'

require 'fig/package'
require 'fig/packagedescriptor'
require 'fig/statement/archive'
require 'fig/statement/include'
require 'fig/statement/path'
require 'fig/statement/resource'
require 'fig/statement/set'

module Fig; end

# Command-line processing.
class Fig::Options
  USAGE = <<-EOF

Usage:

  fig [...] [DESCRIPTOR] [--update | --update-if-missing] [-- COMMAND]

  fig {--publish | --publish-local} DESCRIPTOR
      [--resource PATH]
      [--archive  PATH]
      [--include  DESCRIPTOR]
      [--force]
      [...]

  fig --clean DESCRIPTOR [...]

  fig --get VARIABLE                                         [DESCRIPTOR] [...]
  fig --list-configs                                         [DESCRIPTOR] [...]
  fig --list-dependencies [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig {--list-local | --list-remote}                                      [...]

  fig {--version | --help}

Not yet implemented:
  fig --list-variables [--list-tree] [--list-all-configs]    [DESCRIPTOR] [...]

A DESCRIPTOR looks like <package name>[/<version>][:<config>] e.g. "foo",
"foo/1.2.3", and "foo/1.2.3:default". Whether ":<config>" and "/<version>" are
required or allowed is dependent upon what your are doing

Standard options (represented as "[...]" above):

      [--set    VARIABLE=VALUE]
      [--append VARIABLE=VALUE]
      [--file PATH] [--no-file]
      [--config CONFIG]
      [--login]
      [--log-level LEVEL] [--log-config PATH]
      [--figrc PATH] [--no-figrc]

Environment variables:

  FIG_REMOTE_URL (required),
  FIG_HOME (path to local repository cache, defaults to $HOME/.fighome).

  EOF

  LOG_LEVELS = %w[ off fatal error warn info debug all ]
  LOG_ALIASES = { 'warning' => 'warn' }

  attr_reader :shell_command
  attr_reader :descriptor
  attr_reader :exit_code

  def initialize(argv)
    strip_shell_command(argv)

    @options = {}

    @options[:home] = ENV['FIG_HOME'] || File.expand_path('~/.fighome')

    parser = new_parser()

    # TODO: Need to catch the exception thrown from parser and retranslate into a fig exception
    begin
      parser.parse!(argv)
    rescue OptionParser::MissingArgument => error
      $stderr.puts "Please provide the #{error}."
      @exit_code = 1
      return
    end

    if not exit_code.nil?
      return
    end

    if argv.size > 1
      $stderr.puts %q<Extra arguments. Should only have a package/version after all other options. Had "> + argv.join(%q<", ">) + %q<" left over.>
      @exit_code = 1
      return
    end

    package_text = argv.first
    if package_text
      @descriptor = Fig::PackageDescriptor.parse(package_text)
    end

    return
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

  def non_command_package_statements()
    return @options[:non_command_package_statements]
  end

  def package_config_file()
    return @options[:package_config_file]
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

  def update?()
    return @options[:update]
  end

  def update_if_missing?()
    return @options[:update_if_missing]
  end

  def updating?()
    return update? || update_if_missing?
  end

  private

  def strip_shell_command(argv)
    argv.each_with_index do |arg, i|
      if arg == '--'
        @shell_command = argv[(i+1)..-1]
        argv.slice!(i..-1)
        break
      end
    end

    return
  end

  def new_parser
    return OptionParser.new do |opts|
      set_up_queries(opts)
      set_up_commands(opts)
      set_up_package_configuration_source(opts)
      set_up_package_statements(opts)
      set_up_remote_repository_access(opts)
      set_up_program_configuration(opts)
    end
  end

  def set_up_queries(opts)
    opts.banner = USAGE
    opts.on('-?', '-h','--help','display this help text') do
      help(opts)
    end

    opts.on('-v', '--version', 'Print fig version') do
      version()
    end

    opts.on(
      '-g',
      '--get VARIABLE',
      'print value of environment variable VARIABLE'
    ) do |get|
      @options[:get] = get
    end

    set_up_listings(opts)

    return
  end

  def set_up_listings(opts)
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

      opts.on(*specification) do
        @options[:listing] = type
      end
    end

    opts.on('--list-tree', 'for listings, output a tree instead of a list') do
      @options[:list_tree] = true
    end

    opts.on('--list-all-configs', 'for listings, follow all configurations of the base package') do
      @options[:list_all_configs] = true
    end

    return
  end

  def set_up_commands(opts)
    opts.on('--clean', 'remove package from $FIG_HOME') do
      @options[:clean] = true
    end

    opts.on(
      '--publish', 'install package in $FIG_HOME and in remote repo'
    ) do |publish|
      @options[:publish] = true
    end

    opts.on(
      '--publish-local', 'install package only in $FIG_HOME'
    ) do |publish_local|
      @options[:publish_local] = true
    end

    return
  end

  def set_up_package_configuration_source(opts)
    opts.on(
      '-c',
      '--config CONFIG',
      %q<apply configuration CONFIG, default is "default">
    ) do |config|
      @options[:config] = config
    end

    @options[:package_config_file] = nil
    opts.on(
      '--file FILE',
      %q<read fig file FILE. Use '-' for stdin. See also --no-file>
    ) do |path|
      @options[:package_config_file] = path
    end

    opts.on(
      '--no-file', 'ignore package.fig file in current directory'
    ) do |path|
      @options[:package_config_file] = :none
    end

    return
  end

  def set_up_package_statements(opts)
    @options[:non_command_package_statements] = []
    opts.on(
      '-p',
      '--append VARIABLE=VALUE',
      'append (actually, prepend) VALUE to environment variable VARIABLE, delimited by separator'
    ) do |var_val|
      var, val = var_val.split('=')
      @options[:non_command_package_statements] << Fig::Statement::Path.new(var, val)
    end

    opts.on(
      '-i',
      '--include DESCRIPTOR',
      'include package/version:config specified in DESCRIPTOR (with any variable prepends) in environment'
    ) do |descriptor|
      @options[:non_command_package_statements] <<
        Fig::Statement::Include.new(Fig::PackageDescriptor.parse(descriptor), {})
    end

    opts.on(
      '-s', '--set VARIABLE=VALUE', 'set environment variable VARIABLE to VALUE'
    ) do |var_val|
      var, val = var_val.split('=')
      @options[:non_command_package_statements] << Fig::Statement::Set.new(var, val)
    end

    @options[:archives] = []
    opts.on(
      '--archive PATH',
      'include PATH archive in package (when using --publish)'
    ) do |path|
      @options[:archives] << Fig::Statement::Archive.new(path)
    end

    @options[:resources] =[]
    opts.on(
      '--resource PATH',
      'include PATH resource in package (when using --publish)'
    ) do |path|
      @options[:resources] << Fig::Statement::Resource.new(path)
    end

    return
  end

  def set_up_remote_repository_access(opts)
    opts.on(
      '-u',
      '--update',
      'check remote repo for updates and download to $FIG_HOME as necessary'
    ) do
      @options[:update] = true
    end

    opts.on(
      '-m',
      '--update-if-missing',
      'check remote repo for updates only if package missing from $FIG_HOME'
    ) do
      @options[:update_if_missing] = true
    end

    opts.on(
      '-l', '--login', 'login to remote repo as a non-anonymous user'
    ) do
      @options[:login] = true
    end

    @options[:force] = nil
    opts.on(
      '--force',
      'force-overwrite existing version of a package to the remote repo'
    ) do |force|
      @options[:force] = force
    end

    return
  end

  def set_up_program_configuration(opts)
    opts.on(
      '--figrc PATH', 'add PATH to configuration used for Fig'
    ) do |path|
      @options[:figrc] = path
    end

    opts.on('--no-figrc', 'ignore ~/.figrc') { @options[:no_figrc] = true }

    opts.on(
      '--log-config PATH', 'use PATH file as configuration for Log4r'
    ) do |path|
      @options[:log_config] = path
    end

    level_list = LOG_LEVELS.join(', ')
    opts.on(
      '--log-level LEVEL',
      LOG_LEVELS,
      LOG_ALIASES,
      'set logging level to LEVEL',
      "  (#{level_list})"
    ) do |log_level|
      @options[:log_level] = log_level
    end

    return
  end

  def help(opts)
    puts opts.help
    puts "        --                           end of fig options; anything after this is used as a command to run\n\n"

    @exit_code = 0

    return
  end

  def version()
    line = nil

    begin
      File.open(
        "#{File.expand_path(File.dirname(__FILE__) + '/../../VERSION')}"
      ) do |file|
        line = file.gets
      end
    rescue
      $stderr.puts 'Could not retrieve version number. Something has mucked with your fig install.'

      @exit_code = 1
      return
    end

    if line !~ /\d+\.\d+\.\d+/
      $stderr.puts %Q<"#{line}" does not look like a version number. Something has mucked with your fig install.>

      @exit_code = 1
      return
    end

    puts File.basename($0) + ' v' + line

    @exit_code = 0
    return
  end
end
