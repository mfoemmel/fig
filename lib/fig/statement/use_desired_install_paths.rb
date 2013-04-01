require 'fig/statement'

module Fig; end

# Flag that "desired-install-paths" are acceptable.
class Fig::Statement::UseDesiredInstallPaths < Fig::Statement
  def initialize(line_column, source_description)
    super(line_column, source_description)
  end

  def statement_type()
    return 'use-desired-install-paths'
  end

  def unparse_as_version(unparser)
    return unparser.use_desired_install_paths(self)
  end

  def minimum_grammar_for_emitting_input()
    return [3, %q<didn't exist prior to v3>]
  end

  def minimum_grammar_for_publishing()
    return [3, %q<didn't exist prior to v3>]
  end
end
