require 'fig/package'
require 'fig/package_descriptor'

module Fig; end
class Fig::Command; end

class Fig::Command::PackageApplier
  attr_reader :synthetic_package_for_command_line

  def initialize(
    base_package,
    environment,
    options,
    descriptor,
    base_config,
    package_source_description
  )
    @base_package                 = base_package
    @environment                  = environment
    @options                      = options
    @descriptor                   = descriptor
    @base_config                  = base_config
    @package_source_description   = package_source_description
  end

  def activate_retrieves()
    @base_package.retrieves.each do |statement|
      @environment.add_retrieve(statement)
    end

    return
  end

  def register_package_with_environment()
    @environment.register_package(@base_package)

    return
  end

  def apply_config_to_environment(ignore_base_config)
    begin
      @synthetic_package_for_command_line =
        synthesize_package_for_command_line_options(ignore_base_config)
      @environment.apply_config(
        @synthetic_package_for_command_line, Fig::Package::DEFAULT_CONFIG, nil
      )
    rescue Fig::NoSuchPackageConfigError => exception
      make_no_such_package_exception_descriptive(exception)
    end

    return
  end

  private

  def config_was_specified_by_user()
    return ! @options.config().nil?                   ||
           @descriptor && ! @descriptor.config().nil?
  end

  def synthesize_package_for_command_line_options(ignore_base_config)
    configuration_statements = []

    if not ignore_base_config
      configuration_statements << Fig::Statement::Include.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        Fig::PackageDescriptor.new(
          @base_package.name(),
          @base_package.version(),
          @base_config,
          :description => @base_package.description
        ),
        @base_package,
        nil
      )
    end

    configuration_statements << @options.environment_statements()

    configuration_statement =
      Fig::Statement::Configuration.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        Fig::Package::DEFAULT_CONFIG,
        configuration_statements.flatten()
      )

    return Fig::Package.new(
      nil,  # Name
      nil,  # Version
      'command-line',
      '.',  # Working
      '.',  # Base
      [configuration_statement],
      :is_synthetic
    )
  end

  def make_no_such_package_exception_descriptive(exception)
    if not @descriptor
      make_no_such_package_exception_descriptive_without_descriptor(exception)
    end

    check_no_such_package_exception_is_for_command_line_package(exception)
    source = derive_exception_source()

    message = %Q<There's no "#{@base_config}" config#{source}.>
    config_names = exception.package.config_names
    if config_names.empty?
      message += ' Actually, there are no configs.'
    else
      example_config =
        config_names.size == 1 ? config_names[0] : 'some_existing_config'
      message += %q< Specify one that does like this: ">
      message += Fig::PackageDescriptor.format(
        @descriptor.name, @descriptor.version, example_config,
      )
      message += %q<".>

      if config_names.size > 1
        message +=
          %Q< The valid configs are "#{config_names.join('", "')}".>
      end
    end

    raise Fig::UserInputError.new(message)
  end

  def make_no_such_package_exception_descriptive_without_descriptor(exception)
    raise exception if config_was_specified_by_user()
    raise exception if not exception.descriptor.nil?

    source = derive_exception_source()
    message =
      %Q<No config was specified and there's no "#{Fig::Package::DEFAULT_CONFIG}" config#{source}.>
    append_config_names message, @base_package.config_names()

    raise Fig::UserInputError.new(message)
  end

  def append_config_names(message, config_names)
    if config_names.size > 1
      message +=
        %Q< The valid configs are "#{config_names.join('", "')}".>
    elsif config_names.size == 1
      message += %Q< The only config is "#{config_names[0]}".>
    else
      message += ' Actually, there are no configs.'
    end

    return
  end

  def check_no_such_package_exception_is_for_command_line_package(exception)
    descriptor = exception.descriptor

    raise exception if
      descriptor.name    && descriptor.name    != @descriptor.name
    raise exception if
      descriptor.version && descriptor.version != @descriptor.version
    raise exception if      descriptor.config  != @base_config

    return
  end

  def derive_exception_source()
    source = @package_source_description

    return source ? %Q< in #{source}> : ''
  end
end
