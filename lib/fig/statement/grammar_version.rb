require 'fig/statement'

module Fig; end

# A statement that declares the syntax that a package is to be serialized in.
class Fig::Statement::GrammarVersion < Fig::Statement
  attr_reader :version

  def initialize(line_column, source_description, version)
    super(line_column, source_description)

    @version = version
  end

  def unparse(indent)
    # Comment out if v1 so that older clients don't have issues.
    return "#{indent}#{version == 1 ? '# ' : ''}grammar v#{version}\n"
  end
end
