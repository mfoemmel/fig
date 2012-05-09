require 'fig/packagedescriptorparseerror'

module Fig; end

# Parsed representation of a package (name/version:config).
class Fig::PackageDescriptor
  include Comparable

  attr_reader :name, :version, :config, :original_string

  def self.format(name, version, config, use_default_config = false)
    string = name || ''

    if version
      string += '/'
      string += version
    end

    if config
      string += ':'
      string += config
    elsif use_default_config
      string += ':default'
    end

    return string
  end

  def self.parse(raw_string, options = {})
    filled_in_options = {}
    filled_in_options.merge!(options)
    filled_in_options[:original_string] = raw_string
    filled_in_options[:require_at_least_one_component] = true

    # Additional checks in validate_component() will take care of the looseness
    # of the regexes.  These just need to ensure that the entire string gets
    # assigned to one component or another.
    return self.new(
      raw_string =~ %r< \A         ( [^:/]+ )    >x ? $1 : nil,
      raw_string =~ %r< \A [^/]* / ( [^:]+  )    >x ? $1 : nil,
      raw_string =~ %r< \A [^:]* : ( .+     ) \z >x ? $1 : nil,
      filled_in_options
    )
  end

  # Options are:
  #
  #   :name                           => { :required | :forbidden }
  #   :version                        => { :required | :forbidden }
  #   :config                         => { :required | :forbidden }
  #   :original_string                => the unparsed form
  #   :require_at_least_one_component => should we have at least one of
  #                                      name, version, and config
  #   :validation_context             => what the descriptor is for
  #   :source_description             => where the descriptor came from,
  #                                      most likely the result of invoking
  #                                      Fig::Statement.position_description().
  def initialize(name, version, config, options = {})
    @name            = name
    @version         = version
    @config          = config
    @original_string = options[:original_string]

    validate_component name,    'name',    :name,    options
    validate_component version, 'version', :version, options
    validate_component config,  'config',  :config,  options
    validate_across_components options
  end

  # Specifically not named :to_s because it doesn't act like that should.
  def to_string(use_default_config = false)
    return Fig::PackageDescriptor.format(
      @name, @version, @config, use_default_config
    )
  end

  def <=>(other)
    return to_string() <=> other.to_string()
  end

  private

  def validate_component(
    value, name, presence_requirement_symbol, options
  )
    validate_component_format(value, name, options)

    case options[presence_requirement_symbol]
    when :required
      if value.nil?
        throw_presence_exception(name, presence_requirement_symbol, options)
      end
    when :forbidden
      if ! value.nil?
        throw_presence_exception(name, presence_requirement_symbol, options)
      end
    else
      # No requirements
    end

    return
  end

  def validate_component_format(value, name, options)
    return if value.nil?

    return if value =~ / \A [a-zA-Z0-9_.-]+ \z /x

    raise Fig::PackageDescriptorParseError.new(
      %Q<Invalid #{name} ("#{value}")#{standard_exception_suffix(options)}>,
      @original_string
    )
  end

  def throw_presence_exception(name, presence_requirement_symbol, options)
    presence = options[presence_requirement_symbol]
    raise Fig::PackageDescriptorParseError.new(
      "Package #{name} #{presence}#{standard_exception_suffix(options)}",
      @original_string
    )
  end

  def validate_across_components(options)
    if ! @version.nil? && @name.nil?
      raise Fig::PackageDescriptorParseError.new(
        "Cannot specify a version without a name#{standard_exception_suffix(options)}",
        @original_string
      )
    end

    return if not options[:require_at_least_one_component]
    if @name.nil? && @version.nil? && @config.nil?
      raise Fig::PackageDescriptorParseError.new(
        "Must specify at least one of name, version, and config#{standard_exception_suffix(options)}",
        @original_string
      )
    end

    return
  end

  def standard_exception_suffix(options)
    original_string = @original_string.nil? ? '' : %Q< ("#{@original_string}")>
    context = options[:validation_context] || ''
    source_description = options[:source_description] || ''

    return " in package descriptor#{original_string}#{context}#{source_description}."
  end
end
