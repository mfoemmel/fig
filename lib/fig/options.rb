require 'optparse'

module Fig
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

      options[:list] = false
      opts.on('--list', 'list packages in local repository') { options[:list] = true }

      options[:includes] = []
      opts.on('-i', '--include PKG', 'include package in environment') { |descriptor| options[:includes] << descriptor }

      options[:sets] = []
      opts.on('-s', '--set VAR=VAL', 'set environment variable') { |var_val| options[:sets] << var_val.split('=') }

      options[:appends] = []
      opts.on('-p', '--append VAR=VAL', 'append environment variable') { |var_val| options[:appends] << var_val.split('=') }

      options[:input] = nil
      opts.on('--file FILE', 'fig file to read (use - for stdin)') { |path| options[:input] = path }
      opts.on('--no-file', 'ignore .fig file in current directory') { |path| options[:input] = :none }

      options[:home] = ENV['FIG_HOME'] || File.expand_path("~/.fighome")
    end

    parser.parse!(argv)

    return options, argv
  end
end
