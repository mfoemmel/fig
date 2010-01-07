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
      opts.banner = "Usage: fig [--debug] [--update] [--config <config>] [-echo <var> | --list | <package> | - <command>]"

      opts.on('-?', '-h','--help','display this help text') do
        puts opts
	exit 1
      end 

      options[:debug] = false
      opts.on('-d', '--debug', 'print debug info') { options[:debug] = true }

      options[:update] = false
      opts.on('-u', '--update', 'check remote repository for updates') { options[:update] = true; options[:retrieve] = true }

      options[:config] = "default"
      opts.on('-c', '--config CFG', 'name of configuration to apply') { |config| options[:config] = config }

      options[:echo] = nil
      opts.on('-g', '--get VAR', 'print value of environment variable') { |echo| options[:echo] = echo }

      options[:publish] = nil
      opts.on('--publish PKG', 'install package in local and remote repositories') { |publish| options[:publish] = publish }

      options[:resources] =[]
      opts.on('--resource PATH', 'resource to include in package (when using --publish)') do |path| 
        options[:resources] << Resource.new(path) 
      end

      options[:archives] =[]
      opts.on('--archive PATH', 'archive to include in package (when using --publish)') do |path| 
        options[:archives] << Archive.new(path)
      end

      options[:list] = false
      opts.on('--list', 'list packages in local repository') { options[:list] = true }

      options[:cleans] = []
      opts.on('--clean PKG', 'remove  package from local repository') { |descriptor| options[:cleans] <<  descriptor }

      options[:modifiers] = []

      opts.on('-i', '--include PKG', 'include package in environment') do |descriptor| 
        package_name, config_name, version_name = parse_descriptor(descriptor)
        options[:modifiers] << Include.new(package_name, config_name, version_name) 
      end

      opts.on('-s', '--set VAR=VAL', 'set environment variable') do |var_val| 
        var, val = var_val.split('=')
        options[:modifiers] << Set.new(var, val) 
      end

      opts.on('-p', '--append VAR=VAL', 'append environment variable') do |var_val| 
        var, val = var_val.split('=')
        options[:modifiers] << Path.new(var, val)
      end

      options[:input] = nil
      opts.on('--file FILE', 'fig file to read (use - for stdin)') { |path| options[:input] = path }
      opts.on('--no-file', 'ignore .fig file in current directory') { |path| options[:input] = :none }

      options[:home] = ENV['FIG_HOME'] || File.expand_path("~/.fighome")
    end

    parser.parse!(argv)

    return options, argv
  end
end
