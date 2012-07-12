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
    # Comment out if v0 so that older clients don't have issues.
    return "#{indent}#{version == 0 ? '# ' : ''}grammar v#{version}\n"
  end

  def minimum_grammar_version_required()
    return version
  end
end
