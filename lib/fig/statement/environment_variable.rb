module Fig; end
class Fig::Statement; end

# A statement that manipulates an environment variable.
module Fig::Statement::EnvironmentVariable
  attr_reader :name, :value

  def minimum_grammar_for_emitting_input()
    return minimum_grammar()
  end

  def minimum_grammar_for_publishing()
    return minimum_grammar()
  end

  private

  def minimum_grammar()
    if value =~ /\s/
      return [1, 'contains whitespace']
    end

    # Can't have octothorpes anywhere in v0 due to comment stripping via
    # regex.
    if value =~ /#/
      return [1, 'contains a "#" character']
    end

    if value =~ / ( ["'] ) /x
      return [1, %Q<contains a "#{$1}" character>]
    end

    return [0]
  end
end
