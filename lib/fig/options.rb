require 'optparse'
require 'fig/package'

module Fig
  def parse_descriptor(descriptor)
    # todo should use treetop for these:
    package_name = descriptor =~ /^([^:\/]+)/ ? $1 : nil
    config_name = descriptor =~ /:([^:\/]+)/ ? $1 : nil
    version_name = descriptor =~ /\/([^:\/]+)/ ? $1 : nil
    return package_name, config_name, version_name
  end

  def parse_options(argv)
    options = {}

    parser = OptionParser.new do |opts|
      opts.banner = <<EOF

Usage: fig [--debug] [--update] [--config <config>] [--get <var> | --list | <package> | -- <command>]

Relevant env vars: FIG_REMOTE_URL (required), FIG_HOME (path to local repository cache, defaults
to $HOME/.fighome).

EOF
      opts.on('-?', '-h','--help','display this help text') do
        puts opts
        puts "\n    --  end of fig options; everything following is a command to run in the fig environment\n\n"
        exit 1
      end

      options[:modifiers] = []

      opts.on('-p', '--append VAR=VAL', 'append (actually, prepend) VAL to environment var VAR, delimited by separator') do |var_val|
        var, val = var_val.split('=')
        options[:modifiers] << Path.new(var, val)
      end

      options[:archives] =[]
      opts.on('--archive FULLPATH', 'include FULLPATH archive in package (when using --publish)') do |path|
        options[:archives] << Archive.new(path)
      end

      options[:cleans] = []
      opts.on('--clean PKG', 'remove package from $FIG_HOME') { |descriptor| options[:cleans] <<  descriptor }

      options[:config] = "default"
      opts.on('-c', '--config CFG', "apply configuration CFG, default is 'default'") { |config| options[:config] = config }

      options[:debug] = false
      opts.on('-d', '--debug', 'print debug info') { options[:debug] = true }

      options[:input] = nil
      opts.on('--file FILE', "read fig file FILE. Use '-' for stdin. See also --no-file") { |path| options[:input] = path }

      options[:force] = nil
      opts.on('--force', 'force-overwrite existing version of a package to the remote repo') { |force| options[:force] = force }

      options[:echo] = nil
      opts.on('-g', '--get VAR', 'print value of environment variable VAR') { |echo| options[:echo] = echo }

      opts.on('-i', '--include PKG', 'include PKG (with any variable prepends) in environment') do |descriptor|
        package_name, config_name, version_name = parse_descriptor(descriptor)
        options[:modifiers] << Include.new(package_name, config_name, version_name, {})
      end

      options[:list] = false
      opts.on('--list', 'list packages in $FIG_HOME') { options[:list] = true }

      options[:list_configs] = []
      opts.on('--list-configs PKG', 'list configurations in package') { |descriptor| options[:list_configs] << descriptor }

      options[:list_remote] = false
      opts.on('--list-remote', 'list packages in remote repo') { options[:list_remote] = true }

      options[:login] = false
      opts.on('-l', '--login', 'login to remote repo as a non-anonymous user') { options[:login] = true }

      opts.on('--no-file', 'ignore package.fig file in current directory') { |path| options[:input] = :none }

      options[:publish] = nil
      opts.on('--publish PKG', 'install PKG in $FIG_HOME and in remote repo') { |publish| options[:publish] = publish }

      options[:publish_local] = nil
      opts.on('--publish-local PKG', 'install package only in $FIG_HOME') { |publish_local| options[:publish_local] = publish_local }

#      opts.on('-o', '--override PKG', 'override version of included package') do |descriptor|
#        package_name, config_name, version_name = parse_descriptor(descriptor)
#        options[:modifiers] << Include.new(package_name, config_name, version_name, {})
#      end

      options[:resources] =[]
      opts.on('--resource FULLPATH', 'include FULLPATH resource in package (when using --publish)') do |path|
        options[:resources] << Resource.new(path)
      end

      opts.on('-s', '--set VAR=VAL', 'set environment variable VAR to VAL') do |var_val|
        var, val = var_val.split('=')
        options[:modifiers] << Set.new(var, val)
      end

      options[:update] = false
      opts.on('-u', '--update', 'check remote repo for updates and download to $FIG_HOME as necessary') { options[:update] = true; options[:retrieve] = true }

      options[:update_if_missing] = false
      opts.on('-m', '--update-if-missing', 'check remote repo for updates only if package missing from $FIG_HOME') { options[:update_if_missing] = true; options[:retrieve] = true }

      options[:home] = ENV['FIG_HOME'] || File.expand_path("~/.fighome")
    end

    parser.parse!(argv)

    return options, argv
  end
end
