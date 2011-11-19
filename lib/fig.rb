require 'rubygems'
require 'net/ftp'
require 'log4r'

require 'fig/environment'
require 'fig/figrc'
require 'fig/logging'
require 'fig/options'
require 'fig/os'
require 'fig/package'
require 'fig/package/configuration'
require 'fig/package/publish'
require 'fig/parser'
require 'fig/repository'
require 'fig/retriever'
require 'fig/userinputerror'
require 'fig/windows'

module Fig
  DEFAULT_FIG_FILE = 'package.fig'

  def parse_descriptor(descriptor)
    # todo should use treetop for these:
    package_name = descriptor =~ %r< ^ ( [^:/]+ ) >x ? $1 : nil
    config_name  = descriptor =~ %r< : ( [^:/]+ ) >x ? $1 : nil
    version_name = descriptor =~ %r< / ( [^:/]+ ) >x ? $1 : nil
    return package_name, config_name, version_name
  end

  def run_fig(argv)
    shell_command = nil
    argv.each_with_index do |arg, i|
      if arg == '--'
        shell_command = argv[(i+1)..-1]
        argv.slice!(i..-1)
        break
      end
    end

    options, argv, exit_value = parse_options(argv)
    if not exit_value.nil?
      return exit_value
    end

    Logging.initialize_pre_configuration(options[:log_level])

    vars = {}
    ENV.each {|key,value| vars[key]=value }

    remote_url = nil
    if options[:update] || options[:publish] || options[:update_if_missing] || options[:list_remote]
      remote_url = ENV['FIG_REMOTE_URL']
      if remote_url.nil?
        $stderr.puts 'Please define the FIG_REMOTE_URL environment variable.'
        return 1
      end
    end

    configuration = FigRC.find(
      options[:figrc],
      remote_url,
      options[:login],
      options[:home],
      options[:no_figrc]
    )

    Logging.initialize_post_configuration(options[:log_config] || configuration['log configuration'], options[:log_level])

    remote_user = nil

    os = OS.new(options[:login])
    repos = Repository.new(
      os,
      File.expand_path(File.join(options[:home], 'repos')),
      remote_url,
      configuration,
      remote_user,
      options[:update],
      options[:update_if_missing]
    )
    retriever = Retriever.new('.')
    # Check to see if this is still happening with the new layers of abstraction.
    at_exit { retriever.save }
    env = Environment.new(os, repos, vars, retriever)

    options[:modifiers].each do |modifier|
      env.apply_config_statement(nil, modifier, nil)
    end

    input = nil
    if options[:input] == :none
      # ignore
    elsif options[:input] == '-'
      input = $stdin.read
    elsif options[:input].nil?
      input = File.read(DEFAULT_FIG_FILE) if File.exist?(DEFAULT_FIG_FILE)
    else
      if File.exist?(options[:input])
        input = File.read(options[:input])
      else
        $stderr.puts %Q<File not found: "#{options[:input]}".>
        return 1
      end
    end

    options[:cleans].each do |descriptor|
      package_name, version_name = descriptor.split('/')
      repos.clean(package_name, version_name)
    end
    if options[:list]
      repos.list_packages.sort.each do |item|
        puts item
      end
      return 0
    end

    if options[:list_remote]
      repos.list_remote_packages.sort.each do |item|
        puts item
      end
      return 0
    end

    if not options[:list_configs].empty?
      options[:list_configs].each do |descriptor|
        package_name, version_name = descriptor.split('/')
        repos.read_local_package(package_name, version_name).configs.each do |config|
          puts config.name
        end
      end
      return 0
    end

    if input
      package = Parser.new(configuration).parse_package('default', 'default', '.', input)
      direct_retrieves=[]
      if options[:update] || options[:update_if_missing]
        package.retrieves.each do |var, path|
          if var =~ %r< ^ \@ ([^/]+) (.*) >x
            direct_retrieves << [$1, $2, path]
          else
            env.add_retrieve(var, path)
          end
        end
      end
      unless options[:publish] || options[:list] || options[:publish_local]
        env.register_package(package)
        env.apply_config(package, options[:config], nil)
        direct_retrieves.each do |info|
          env.direct_retrieve(info[0], info[1], info[2])
        end
      end
    else
      package = Package.new(nil, nil, '.', [])
    end

    if options[:publish] || options[:publish_local]
      if !argv.empty?
        $stderr.puts %Q<Unexpected arguments: #{argv.join(' ')}>
        return 10
      end
      package_name, config_name, version_name = parse_descriptor(options[:publish] || options[:publish_local])
      if package_name.nil? || version_name.nil?
        $stderr.puts 'Please specify a package name and a version name.'
        return 10
      end
      if not options[:modifiers].empty?
        publish_statements = options[:resources] + options[:archives] + [Package::Configuration.new('default', options[:modifiers])]
        publish_statements << Package::Publish.new('default','default')
      elsif not package.statements.empty?
        publish_statements = package.statements
      else
        $stderr.puts 'Nothing to publish.'
        return 1
      end
      if options[:publish]
        Logging.info "Checking status of #{package_name}/#{version_name}..."
        if repos.list_remote_packages.include?("#{package_name}/#{version_name}")
          Logging.info "#{package_name}/#{version_name} has already been published."
          if not options[:force]
            Logging.fatal 'Use the --force option if you really want to overwrite, or use --publish-local for testing.'
            return 1
          else
            Logging.info 'Overwriting...'
          end
        end
      end
      Logging.info "Publishing #{package_name}/#{version_name}."
      repos.publish_package(publish_statements, package_name, version_name, options[:publish_local])
    elsif options[:echo]
      puts env[options[:echo]]
    elsif shell_command
      argv.shift
      env.execute_shell(shell_command) { |cmd| os.shell_exec cmd }
    elsif argv[0]
      package_name, config_name, version_name = parse_descriptor(argv.shift)
      env.include_config(package, package_name, config_name, version_name, {}, nil)
      env.execute_config(package, package_name, config_name, nil, argv) { |cmd| os.shell_exec cmd }
    elsif not argv.empty?
      env.execute_config(package, nil, options[:config], nil, argv) { |cmd| os.shell_exec cmd }
    elsif not repos.updating?
      $stderr.puts "Nothing to do.\n"
      $stderr.puts USAGE
      $stderr.puts %q<Run "fig --help" for a full list of commands.>
      return 1
    end

    return 0
  end

  def run_with_exception_handling(argv)
    begin
      return_code = run_fig(argv)
      return return_code
    rescue URLAccessError => exception
      urls = exception.urls.join(', ')
      $stderr.puts "Access to #{urls} in #{exception.package}/#{exception.version} not allowed."
      return 1
    rescue UserInputError => exception
      # If there's no message, we assume that the cause has already been logged.
      if not exception_has_message?(exception)
        $stderr.puts exception.to_s
      end

      return 1
    rescue OptionParser::InvalidOption => exception
      $stderr.puts exception.to_s
      $stderr.puts USAGE
      return 1
    end
  end

  def exception_has_message?(exception)
    class_name = exception.class.name
    return exception.message == class_name
  end
end
