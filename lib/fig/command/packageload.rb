require 'fig/package'
require 'fig/packagedescriptor'
require 'fig/parser'

module Fig; end
class Fig::Command; end

# Parts of the Command class related to loading of the primary Package object,
# simply to keep the size of command.rb down.
module Fig::Command::PackageLoad
  DEFAULT_FIG_FILE = 'package.fig'

  private

  def read_in_package_config_file(config_file)
    if File.exist?(config_file)
      @package_loaded_from_path = config_file

      return File.read(config_file)
    else
      raise Fig::UserInputError.new(%Q<File not found: "#{config_file}".>)
    end
  end

  def load_package_config_file_contents()
    package_config_file = @options.package_config_file()

    if package_config_file == :none
      return nil
    elsif package_config_file == '-'
      @package_loaded_from_path = '<standard input>'

      return $stdin.read
    elsif package_config_file.nil?
      if File.exist?(DEFAULT_FIG_FILE)
        @package_loaded_from_path = DEFAULT_FIG_FILE

        return File.read(DEFAULT_FIG_FILE)
      end
    else
      return read_in_package_config_file(package_config_file)
    end

    return
  end

  def register_package_with_environment_if_not_listing()
    return if @options.listing

    register_package_with_environment()

    return
  end

  def register_package_with_environment()
    if @options.updating?
      @package.retrieves.each do |var, path|
        @environment.add_retrieve(var, path)
      end
    end

    @environment.register_package(@package)

    config =
      @options.config()                       ||
      @descriptor && @descriptor.config()     ||
      Fig::Package::DEFAULT_CONFIG
    begin
      @environment.apply_config(@package, config, nil)
    rescue Fig::NoSuchPackageConfigError => exception
      raise exception if not @descriptor

      descriptor = exception.descriptor

      raise exception if
        descriptor.name    && descriptor.name    != @descriptor.name
      raise exception if
        descriptor.version && descriptor.version != @descriptor.version
      raise exception if      descriptor.config  != config

      source = nil
      if @package_loaded_from_path
        source = @package_loaded_from_path
      else
        source = %Q<#{descriptor.name}/#{descriptor.version}>
      end
      source_component = source ? %Q< in #{source}> : ''

      message =
        %Q<There's no "#{config}" configuration#{source_component}. Specify one that does like this: "#{@descriptor.name}/#{@descriptor.version}:some_existing_config".>

      if @options.publishing?
        message += ' (Yes, this does work with --publish.)'
      end

      raise Fig::UserInputError.new(message)
    end

    return
  end

  def parse_package_config_file(config_raw_text)
    if config_raw_text.nil?
      @package = Fig::Package.new(nil, nil, '.', [])
      return
    end

    @package =
      Fig::Parser.new(@configuration).parse_package(
        Fig::PackageDescriptor.new(nil, nil, nil), '.', config_raw_text
      )

    register_package_with_environment_if_not_listing()

    return
  end

  def load_package_file()
    config_raw_text = load_package_config_file_contents()

    parse_package_config_file(config_raw_text)
  end

  def load_package_object()
    if @descriptor.nil?
      load_package_file()
    else
      # TODO: complain if config file was specified on the command-line.
      @package = @repository.get_package(@descriptor)

      register_package_with_environment_if_not_listing()
    end

    return
  end
end
