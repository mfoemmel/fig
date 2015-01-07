# coding: utf-8

require 'fig/statement'

module Fig; end

# A statement that declares the syntax that a package is to be serialized in.
class Fig::Statement::GrammarVersion < Fig::Statement
  attr_reader :version

  def initialize(line_column, source_description, version)
    super(line_column, source_description)

    @version = version
  end

  def statement_type()
    return 'grammar'
  end

  def deparse_as_version(deparser)
    return deparser.grammar_version(self)
  end

  def minimum_grammar_for_emitting_input()
    return [version]
  end

  def minimum_grammar_for_publishing()
    return [version]
  end
end
