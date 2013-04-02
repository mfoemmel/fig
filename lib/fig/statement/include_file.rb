require 'fig/package_descriptor'
require 'fig/statement'
require 'fig/user_input_error'

module Fig; end

# Like an include, but of an unpublished file.
class Fig::Statement::IncludeFile < Fig::Statement
  def self.parse_path_with_config(path_with_config, &block)
    if match = PATH_WITH_CONFIG_PATTERN.match(path_with_config)
      return validate_and_process_raw_path_and_config_name(
        match[:path], match[:config], &block
      )
    end

    yield 'could not be understood as a path followed by a config name.'
    return
  end

  def self.validate_and_process_raw_path_and_config_name(
    raw_path, config_name, &block
  )
    if raw_path !~ /['"]/ && raw_path =~ /:/
      yield 'has an unquoted colon (:) in the path portion.'
      return
    end
    if (
      ! config_name.nil? &&
      config_name !~ Fig::PackageDescriptor::COMPONENT_PATTERN
    )
      yield "contains an invalid config name (#{config_name})."
      return
    end
    tokenized_path = validate_and_process_escapes_in_path(raw_path, &block)
    return if tokenized_path.nil?

    return tokenized_path.to_expanded_string, config_name
  end

  private

  def self.validate_and_process_escapes_in_path(path, &block)
    return Fig::StringTokenizer.new.tokenize(path, &block)
  end


  public

  attr_reader :path
  attr_reader :config_name
  attr_reader :containing_package_descriptor

  def initialize(
    line_column,
    source_description,
    path,
    config_name,
    containing_package_descriptor
  )
    super(line_column, source_description)

    @path                          = path
    @config_name                   = config_name
    @containing_package_descriptor = containing_package_descriptor
  end

  def statement_type()
    return 'include-file'
  end

  def deparse_as_version(deparser)
    return deparser.include_file(self)
  end

  def minimum_grammar_for_emitting_input()
    return [2, %q<didn't exist prior to v2>]
  end

  def minimum_grammar_for_publishing()
    raise Fig::UserInputError.new 'Cannot publish an include-file statement.'
  end

  private

  PATH_WITH_CONFIG_PATTERN = /
    \A
    (?<path> .+?)
    (?:
      [:]
      (?<config> #{Fig::PackageDescriptor::UNBRACKETED_COMPONENT_PATTERN})
    )?
    \z
  /x
end
