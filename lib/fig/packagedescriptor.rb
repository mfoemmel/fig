module Fig; end

# Parsed representation of a package name:config/version.
class Fig::PackageDescriptor
  include Comparable

  DEFAULT_CONFIG = 'default'

  attr_reader :name, :version, :config

  def initialize(raw_string)
    # todo should use treetop for these:
    @name    = raw_string =~ %r< ^ ( [^:/]+ ) >x ? $1 : nil
    @config  = raw_string =~ %r< : ( [^:/]+ ) >x ? $1 : nil
    @version = raw_string =~ %r< / ( [^:/]+ ) >x ? $1 : nil
  end

  def to_string(use_default_config = false)
    string = @name || ''

    if @version
      string += '/'
      string += @version
    end

    if @config
      string += ':'
      string += @config
    elsif use_default_config
      string += ':default'
    end

    return string
  end

  def <=>(other)
    return to_string() <=> other.to_string()
  end
end
