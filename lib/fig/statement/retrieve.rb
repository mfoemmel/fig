require 'fig/logging'
require 'fig/operating_system'
require 'fig/statement'

module Fig; end

# Specifies that files from a package should be copied into the current
# directory when an environment variable has its value changed.
class Fig::Statement::Retrieve < Fig::Statement
  attr_reader   :var, :path

  def initialize(line_column, source_description, var, path)
    super(line_column, source_description)

    @var = var
    @path = path

    # Yeah, it's not cross-platform, but File doesn't have an #absolute? method
    # and this is better than nothing.
    if (
          path =~ %r< ^ [\\/] >x \
      ||  Fig::OperatingSystem.windows? && path =~ %r< ^ [a-z] : >xi
    )
      Fig::Logging.warn(
        %Q<The retrieve path "#{path}"#{position_string()} looks like it is intended to be absolute; retrieve paths are always treated as relative.>
      )
    end
  end

  def loaded_but_not_referenced?()
    return added_to_environment? && ! referenced?
  end

  def added_to_environment?()
    return @added_to_environment
  end

  def added_to_environment(yea_or_nay)
    @added_to_environment = yea_or_nay
  end

  def referenced?()
    return @referenced
  end

  def referenced(yea_or_nay)
    @referenced = yea_or_nay
  end

  def unparse_as_version(unparser)
    return unparser.retrieve(self)
  end

  def minimum_grammar_for_emitting_input()
    return [0]
  end

  def minimum_grammar_for_publishing()
    return [0]
  end
end
