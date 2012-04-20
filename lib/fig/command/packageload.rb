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

  def register_package_with_environment_if_not_listing_or_publishing()
    return if @options.listing || @options.publishing?

    register_package_with_environment()

    return
  end

  def register_package_with_environment()
    if @options.updating?
      @package.retrieves.each do |statement|
        @environment.add_retrieve(statement)
      end
    end

    @environment.register_package(@package)

    begin
      @environment.apply_config(@package, base_config(), nil)
    rescue Fig::NoSuchPackageConfigError => exception
      make_no_such_package_exception_descriptive(exception)
    end

    return
  end

  def parse_package_config_file(config_raw_text)
    if config_raw_text.nil?
      @package = Fig::Package.new(nil, nil, '.', [])
      return
    end

    @package =
      Fig::Parser.new(@configuration, :check_include_versions).parse_package(
        Fig::PackageDescriptor.new(nil, nil, nil), '.', config_raw_text
      )

    register_package_with_environment_if_not_listing_or_publishing()

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
      @package = @repository.get_package(@descriptor)

      register_package_with_environment_if_not_listing_or_publishing()
    end

    return
  end

  def make_no_such_package_exception_descriptive(exception)
    if not @descriptor
      raise exception if config_was_specified_by_user()

      source = derive_exception_source()
      message =
        %Q<No config was specified and there's no "#{Fig::Package::DEFAULT_CONFIG}" config#{source}.>
      message +=
        %Q< The valid configs are "#{@package.config_names().join('", "')}".>

      raise Fig::UserInputError.new(message)
    end

    check_no_such_package_exception_is_for_command_line_package(exception)
    source = derive_exception_source()

    message = %Q<There's no "#{base_config()}" config#{source}.>
    message += %q< Specify one that does like this: ">
    message +=
      Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, 'some_existing_config')
    message += %q<".>

    if @options.publishing?
      message += ' (Yes, this does work with --publish.)'
    end

    raise Fig::UserInputError.new(message)
  end

  def check_no_such_package_exception_is_for_command_line_package(exception)
    descriptor = exception.descriptor

    raise exception if
      descriptor.name    && descriptor.name    != @descriptor.name
    raise exception if
      descriptor.version && descriptor.version != @descriptor.version
    raise exception if      descriptor.config  != base_config()

    return
  end

  def derive_exception_source()
    source = nil
    if @package_loaded_from_path
      source = @package_loaded_from_path
    elsif @descriptor
      source =
        Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, nil)
    end

    return source ? %Q< in #{source}> : ''
  end
end
