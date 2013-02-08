require 'fig/package_descriptor'
require 'fig/statement'

module Fig; end

# Like an include, but of an unpublished file.
class Fig::Statement::IncludeFile < Fig::Statement
  attr_reader :path
  attr_reader :config_name
  attr_reader :containing_package_descriptor

  def initialize(line_column, source_description, path, config_name, containing_package_descriptor)
    super(line_column, source_description)

    @path                          = path
    @config_name                   = config_name
    @containing_package_descriptor = containing_package_descriptor
  end

  def statement_type()
    return 'include-file'
  end

  def unparse_as_version(unparser)
    return unparser.include-version(self)
  end

  def minimum_grammar_for_emitting_input()
    return [2, %q<didn't exist prior to v2>]
  end

  def minimum_grammar_for_publishing()
    raise 'Cannot publish an include-file statement.'
  end
end
