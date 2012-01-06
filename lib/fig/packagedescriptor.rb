module Fig; end

# Parsed representation of a package name:config/version.
class Fig::PackageDescriptor
  attr_reader :name, :version, :config

  def initialize(raw_string)
    # todo should use treetop for these:
    @name    = raw_string =~ %r< ^ ( [^:/]+ ) >x ? $1 : nil
    @config  = raw_string =~ %r< : ( [^:/]+ ) >x ? $1 : nil
    @version = raw_string =~ %r< / ( [^:/]+ ) >x ? $1 : nil
  end
end
