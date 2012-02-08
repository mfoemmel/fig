module Fig; end

# Parsed representation of a package (name/version:config).
class Fig::PackageDescriptor
  include Comparable

  attr_reader :name, :version, :config

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

  def self.parse(raw_string)
    # Additional checks in validate_component() will take care of the looseness
    # of the regexes.  These just need to ensure that the entire string gets
    # assigned to one component or another.

    self.new(
      raw_string =~ %r< \A         ( [^:/]+ )    >x ? $1 : nil,
      raw_string =~ %r< \A [^/]* / ( [^:]+  )    >x ? $1 : nil,
      raw_string =~ %r< \A [^:]* : ( .+     ) \z >x ? $1 : nil
    )
  end

  def initialize(name, version, config)
    @name     = name
    @version  = version
    @config   = config
  end

  def validate_component(value, name)
    return if value.nil?

    return if value =~ / \A [a-zA-Z0-9_.-]+ \z /x

    raise %Q<Invalid #{name} for package descriptor: "#{value}".>
  end

  def to_string(use_default_config = false)
    return Fig::PackageDescriptor.format(@name, @version, @config, use_default_config)
  end

  def <=>(other)
    return to_string() <=> other.to_string()
  end
end
