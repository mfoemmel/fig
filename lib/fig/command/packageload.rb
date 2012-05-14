require 'fig/package'
require 'fig/packagedescriptor'
require 'fig/parser'

module Fig; end
class Fig::Command; end

# Parts of the Command class related to loading of the base Package object,
# simply to keep the size of command.rb down.
module Fig::Command::PackageLoad
  DEFAULT_FIG_FILE = 'package.fig'

  private

  def read_in_package_definition_file(config_file)
    if File.exist?(config_file)
      @package_loaded_from_path = config_file

      return File.read(config_file)
    else
      raise Fig::UserInputError.new(%Q<File "#{config_file}" does not exist.>)
    end
  end

  def load_package_definition_file_contents()
    package_definition_file = @options.package_definition_file()

    if package_definition_file == :none
      return nil
    elsif package_definition_file == '-'
      @package_loaded_from_path = '<standard input>'

      return $stdin.read
    elsif package_definition_file.nil?
      if File.exist?(DEFAULT_FIG_FILE)
        @package_loaded_from_path = DEFAULT_FIG_FILE

        return File.read(DEFAULT_FIG_FILE)
      end
    else
      return read_in_package_definition_file(package_definition_file)
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
      @environment.apply_config(
        synthesize_package_for_command_line_options(),
        Fig::Package::DEFAULT_CONFIG,
        nil
      )
    rescue Fig::NoSuchPackageConfigError => exception
      make_no_such_package_exception_descriptive(exception)
    end

    return
  end

  def parse_package_definition_file(config_raw_text)
    if config_raw_text.nil?
      # This package gets a free ride in terms of requiring a base config; we
      # synthesize it.
      @package = Fig::Package.new(
        nil,
        nil,
        '.',
        [
          Fig::Statement::Configuration.new(
            nil,
            %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
            base_config(),
            []
          )
        ]
      )
      return
    end

    source_description = derive_package_source_description()
    @package =
      Fig::Parser.new(@configuration, :check_include_versions).parse_package(
        Fig::PackageDescriptor.new(
          nil, nil, nil, :source_description => source_description
        ),
        '.',
        source_description,
        config_raw_text
      )

    return
  end

  def load_package_file()
    config_raw_text = load_package_definition_file_contents()

    parse_package_definition_file(config_raw_text)
  end

  def load_package_object()
    if @descriptor.nil?
      load_package_file()
    else
      @package = @repository.get_package(@descriptor)
    end

    register_package_with_environment_if_not_listing_or_publishing()

    return
  end

  def synthesize_package_for_command_line_options()
    include_statement = Fig::Statement::Include.new(
      nil,
      %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
      Fig::PackageDescriptor.new(
        @package.name(), @package.version(), base_config()
      ),
      nil
    )
    configuration_statement =
      Fig::Statement::Configuration.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        Fig::Package::DEFAULT_CONFIG,
        [@options.environment_statements(), include_statement].flatten()
      )

    return Fig::Package.new(nil, nil, '.', [configuration_statement])
  end

  def make_no_such_package_exception_descriptive(exception)
    if not @descriptor
      make_no_such_package_exception_descriptive_without_descriptor(exception)
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

  def make_no_such_package_exception_descriptive_without_descriptor(exception)
    raise exception if config_was_specified_by_user()
    raise exception if not exception.descriptor.nil?

    source = derive_exception_source()
    message =
      %Q<No config was specified and there's no "#{Fig::Package::DEFAULT_CONFIG}" config#{source}.>
    config_names = @package.config_names()
    if config_names.size > 1
      message +=
        %Q< The valid configs are "#{config_names.join('", "')}".>
    elsif config_names.size == 1
      message += %Q< The only config is "#{config_names[0]}".>
    else
      message += ' Actually, there are no configs.'
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
    source = derive_package_source_description()

    return source ? %Q< in #{source}> : ''
  end

  def derive_package_source_description()
    if @package_loaded_from_path
      return @package_loaded_from_path
    elsif @descriptor
      return
        Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, nil)
    end

    return nil
  end
end
