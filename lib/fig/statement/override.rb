require 'fig/package_descriptor'
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

  # Centralized definition of requirements for descriptors for override
  # statements.
  def self.parse_descriptor(raw_string, options = {})
    filled_in_options = {}
    filled_in_options.merge!(options)
    filled_in_options[:name]    = :required
    filled_in_options[:version] = :required
    filled_in_options[:config]  = :forbidden

    return Fig::PackageDescriptor.parse(raw_string, filled_in_options)
  end

  def initialize(line_column, source_description, package_name, version)
    super(line_column, source_description)

    @package_name = package_name
    @version = version
  end

  def unparse(indent)
    return "#{indent}override " +
      Fig::PackageDescriptor.format(@package_name, @version, nil)
  end

  def minimum_grammar_version_required()
    return 0
  end
end
