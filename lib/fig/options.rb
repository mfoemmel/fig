require 'optparse'
require 'fig/package'
require 'fig/package/archive'
require 'fig/package/include'
require 'fig/package/path'
require 'fig/package/resource'
require 'fig/package/set'

module Fig
  def parse_descriptor(descriptor)
    # todo should use treetop for these:
    package_name = descriptor =~ /^([^:\/]+)/ ? $1 : nil
    config_name = descriptor =~ /:([^:\/]+)/ ? $1 : nil
    version_name = descriptor =~ /\/([^:\/]+)/ ? $1 : nil
    return package_name, config_name, version_name
  end

  USAGE = <<EOF

Usage: fig [--debug] [--update] [--config <config>] [--get <var> | --list | <package> | -- <command>]

Relevant env vars: FIG_REMOTE_URL (required), FIG_HOME (path to local repository cache, defaults
to $HOME/.fighome).

EOF

  LOG_LEVELS = %w[ off fatal error warn info debug all ]
  LOG_ALIASES = { 'warning' => 'warn' }

  # Returns hash of option values, the remainders of argv, and an exit code if
  # full program processing occured in this method, otherwise nil.
  def parse_options(argv)
    options = {}

    parser = OptionParser.new do |opts|
      opts.banner = USAGE
      opts.on('-?', '-h','--help','display this help text') do
        puts opts.help
        puts "\n    --  end of fig options; everything following is a command to run in the fig environment.\n\n"
        return nil, nil, 0
      end

      opts.on('-v', '--version', 'Print fig version') do
        line = nil

        begin
          File.open(
            "#{File.expand_path(File.dirname(__FILE__) + '/../../VERSION')}"
          ) do |file|
            line = file.gets
          end
        rescue
          $stderr.puts 'Could not retrieve version number. Something has mucked with your gem install.'
          return nil, nil, 1
        end

        if line !~ /\d+\.\d+\.\d+/
          $stderr.puts %Q<"#{line}" does not look like a version number. Something has mucked with your gem install.>
          return nil, nil, 1
        end

        puts File.basename($0) + ' v' + line

        return nil, nil, 0
      end

      options[:modifiers] = []
      opts.on(
        '-p',
        '--append VAR=VAL',
        'append (actually, prepend) VAL to environment var VAR, delimited by separator'
      ) do |var_val|
        var, val = var_val.split('=')
        options[:modifiers] << Package::Path.new(var, val)
      end

      options[:archives] = []
      opts.on(
        '--archive FULLPATH',
        'include FULLPATH archive in package (when using --publish)'
      ) do |path|
        options[:archives] << Package::Archive.new(path)
      end

      options[:cleans] = []
      opts.on('--clean PKG', 'remove package from $FIG_HOME') do |descriptor|
        options[:cleans] << descriptor
      end

      options[:config] = 'default'
      opts.on(
        '-c',
        '--config CFG',
        %q<apply configuration CFG, default is 'default'>
      ) do |config|
        options[:config] = config
      end

      options[:debug] = false
      opts.on('-d', '--debug', 'print debug info') do
        options[:debug] = true
      end

      options[:input] = nil
      opts.on(
        '--file FILE',
        %q<read fig file FILE. Use '-' for stdin. See also --no-file>
      ) do |path|
        options[:input] = path
      end

      options[:force] = nil
      opts.on(
        '--force',
        'force-overwrite existing version of a package to the remote repo'
      ) do |force|
        options[:force] = force
      end

      options[:echo] = nil
      opts.on(
        '-g',
        '--get VAR',
        'print value of environment variable VAR'
      ) do |echo|
        options[:echo] = echo
      end

      opts.on(
        '-i',
        '--include PKG',
        'include PKG (with any variable prepends) in environment'
      ) do |descriptor|
        package_name, config_name, version_name = parse_descriptor(descriptor)
        options[:modifiers] << Package::Include.new(package_name, config_name, version_name, {})
      end

      options[:list] = false
      opts.on('--list', 'list packages in $FIG_HOME') do
        options[:list] = true
      end

      options[:list_configs] = []
      opts.on(
        '--list-configs PKG', 'list configurations in package'
      ) do |descriptor|
        options[:list_configs] << descriptor
      end

      options[:list_remote] = false
      opts.on('--list-remote', 'list packages in remote repo') do
        options[:list_remote] = true
      end

      options[:login] = false
      opts.on(
        '-l', '--login', 'login to remote repo as a non-anonymous user'
      ) do
        options[:login] = true
      end

      opts.on(
        '--no-file', 'ignore package.fig file in current directory'
      ) do |path|
        options[:input] = :none
      end

      options[:publish] = nil
      opts.on(
        '--publish PKG', 'install PKG in $FIG_HOME and in remote repo'
      ) do |publish|
        options[:publish] = publish
      end

      options[:publish_local] = nil
      opts.on(
        '--publish-local PKG', 'install package only in $FIG_HOME'
      ) do |publish_local|
        options[:publish_local] = publish_local
      end

      options[:resources] =[]
      opts.on(
        '--resource FULLPATH',
        'include FULLPATH resource in package (when using --publish)'
      ) do |path|
        options[:resources] << Package::Resource.new(path)
      end

      opts.on(
        '-s', '--set VAR=VAL', 'set environment variable VAR to VAL'
      ) do |var_val|
        var, val = var_val.split('=')
        options[:modifiers] << Package::Set.new(var, val)
      end

      options[:update] = false
      opts.on(
        '-u',
        '--update',
        'check remote repo for updates and download to $FIG_HOME as necessary'
      ) do
        options[:update] = true; options[:retrieve] = true
      end

      options[:update_if_missing] = false
      opts.on(
        '-m',
        '--update-if-missing',
        'check remote repo for updates only if package missing from $FIG_HOME'
      ) do
        options[:update_if_missing] = true; options[:retrieve] = true
      end

      opts.on(
        '--figrc PATH', 'add PATH to configuration used for Fig'
      ) do |path|
        options[:figrc] = path
      end

      opts.on('--no-figrc', 'ignore ~/.figrc') { options[:no_figrc] = true }

      opts.on(
        '--log-config PATH', 'use PATH file as configuration for Log4r'
      ) do |path|
        options[:log_config] = path
      end

      level_list = LOG_LEVELS.join(', ')
      opts.on(
        '--log-level LEVEL',
        LOG_LEVELS,
        LOG_ALIASES,
        'set logging level to LEVEL',
        "  (#{level_list})"
      ) do |log_level|
        options[:log_level] = log_level
      end

      options[:home] = ENV['FIG_HOME'] || File.expand_path('~/.fighome')
    end

    # Need to catch the exception thrown from parser and retranslate into a fig exception
    parser.parse!(argv)

    return options, argv, nil
  end
end
