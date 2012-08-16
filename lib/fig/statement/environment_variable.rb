module Fig; end
class Fig::Statement; end

# A statement that manipulates an environment variable.
module Fig::Statement::EnvironmentVariable
  def minimum_grammar_for_emitting_input()
    # TODO: fix this once going through
    # Statement.strip_quotes_and_process_escapes()
    return [0]
  end

  def minimum_grammar_for_publishing()
    # TODO: fix this once going through
    # Statement.strip_quotes_and_process_escapes()
    return [0]
  end
end
