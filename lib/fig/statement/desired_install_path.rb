require 'fig/statement'

module Fig; end

# Specification of absolute path this package wants to end up in.
class Fig::Statement::DesiredInstallPath < Fig::Statement
  attr_reader :path

  def initialize(line_column, source_description, path)
    super(line_column, source_description)

    @path = path
  end

  def statement_type()
    return 'desired-install-path'
  end

  def unparse_as_version(unparser)
    return unparser.desired_install_path(self)
  end

  def minimum_grammar_for_emitting_input()
    return [3, %q<didn't exist prior to v3>]
  end

  def minimum_grammar_for_publishing()
    return [3, %q<didn't exist prior to v3>]
  end
end
