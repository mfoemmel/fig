require 'fig/statement'

module Fig; end

# Some raw text that we want emitted as part of unparsing.
class Fig::Statement::SyntheticRawText < Fig::Statement
  attr_reader :text

  def initialize(line_column, source_description, text)
    super(line_column, source_description)

    @text = text
  end

  def statement_type()
    return nil
  end

  def unparse_as_version(unparser)
    return unparser.synthetic_raw_text(self)
  end

  def minimum_grammar_for_emitting_input()
    return [0]
  end

  def minimum_grammar_for_publishing()
    return [0]
  end
end
