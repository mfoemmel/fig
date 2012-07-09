require 'fig/package_descriptor'
require 'fig/parser'

module Fig; end
class Fig::Command; end

class Fig::Command::PackageLoader
  DEFAULT_FIG_FILE = 'package.fig'

  def initialize(
    application_configuration,
    descriptor,
    package_definition_file,
    base_config,
    repository
  )
    @application_configuration    = application_configuration
    @descriptor                   = descriptor
    @package_definition_file      = package_definition_file
    @base_config                  = base_config
    @repository                   = repository
  end

  def load_package_object_from_file()
    definition_text = load_package_definition_file_contents()

    parse_package_definition_file(definition_text)

    return @base_package
  end

  def load_package_object()
    if @descriptor.nil?
      load_package_object_from_file()
    else
      @base_package = @repository.get_package(@descriptor)
    end

    return @base_package
  end

  def package_source_description()
    if @package_loaded_from_path
      return @package_loaded_from_path
    elsif @descriptor
      return
        Fig::PackageDescriptor.format(@descriptor.name, @descriptor.version, nil)
    end

    return nil
  end

  private

  def load_package_definition_file_contents()
    if @package_definition_file == :none
      return nil
    elsif @package_definition_file == '-'
      @package_loaded_from_path = '<standard input>'

      return $stdin.read
    elsif @package_definition_file.nil?
      if File.exist?(DEFAULT_FIG_FILE)
        @package_loaded_from_path = DEFAULT_FIG_FILE

        return File.read(DEFAULT_FIG_FILE)
      end
    else
      return read_in_package_definition_file(@package_definition_file)
    end

    return
  end

  def read_in_package_definition_file(config_file)
    if File.exist?(config_file)
      @package_loaded_from_path = config_file

      return File.read(config_file)
    else
      raise Fig::UserInputError.new(%Q<File "#{config_file}" does not exist.>)
    end
  end

  def parse_package_definition_file(definition_text)
    if definition_text.nil?
      # This package gets a free ride in terms of requiring a base config; we
      # synthesize it.
      set_base_package_to_empty_synthetic_one()
      return
    end

    source_description = package_source_description()

    @base_package =
      Fig::Parser.new(@application_configuration, :check_include_versions).parse_package(
        Fig::PackageDescriptor.new(
          nil, nil, nil, :source_description => source_description
        ),
        '.',
        source_description,
        definition_text
      )

    return
  end

  def set_base_package_to_empty_synthetic_one()
    @base_package = Fig::Package.new(
      nil,
      nil,
      '.',
      [
        Fig::Statement::Configuration.new(
          nil,
          %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
          @base_config,
          []
        )
      ]
    )

    return
  end
end
