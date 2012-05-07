require 'fig/packagedescriptor'
require 'fig/statement'

module Fig; end

# Overrides one package version dependency with another.
#
#   config whatever
#     override somedependency/3.2.6
#   end
#
# indicates that, regardless of which version of somedependency the blah
# package says it needs, the blah package will actually use v3.2.6.
class Fig::Statement::Override < Fig::Statement
  attr_reader :package_name, :version

  def initialize(line_column, source_description, package_name, version)
    super(line_column, source_description)

    @package_name = package_name
    @version = version
  end

  def unparse(indent)
    return "#{indent}override " +
      Fig::PackageDescriptor.format(@package_name, @version, nil)
  end
end
