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
    # Additional checks in validate_component() will take care of the looseness
    # of the regexes.  These just need to ensure that the entire string gets
    # assigned to one component or another.

    options = Hash.new options
    options[:original_string] = raw_string

    self.new(
      raw_string =~ %r< \A         ( [^:/]+ )    >x ? $1 : nil,
      raw_string =~ %r< \A [^/]* / ( [^:]+  )    >x ? $1 : nil,
      raw_string =~ %r< \A [^:]* : ( .+     ) \z >x ? $1 : nil,
      options
    )
  end

  # "options
  def initialize(name, version, config, options = {})
    @name            = name
    @version         = version
    @config          = config
    @original_string = options[:original_string]

    validate_component name,    'name',    :name,    options
    validate_component version, 'version', :version, options
    validate_component config,  'config',  :config,  options

    if ! version.nil? && name.nil?
      Fig::PackageDescriptorParseError.new(
        'Cannot specify a version without a name.', @original_string
      )
    end
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
        raise Fig::PackageDescriptorParseError.new(
          "#{name} required", @original_string
        )
      end
    when :forbidden
      if ! value.nil?
        raise Fig::PackageDescriptorParseError.new(
          "#{name} forbidden", @original_string
        )
      end
    else
      # No requirements
    end

    return
  end


  def validate_component_format(value, name, options)
    return if value.nil?

    return if value =~ / \A [a-zA-Z0-9_.-]+ \z /x

    source_description = options[:source_description] || ''
    raise Fig::PackageDescriptorParseError.new(
      %Q<Invalid #{name} ("#{value}") for package descriptor#{source_description}.>,
      self.original_string
    )
  end
end
