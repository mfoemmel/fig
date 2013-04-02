require 'fig/logging'
require 'fig/operating_system'
require 'fig/statement'

module Fig; end

# Specifies that files from a package should be copied into the current
# directory when an environment variable has its value changed.
class Fig::Statement::Retrieve < Fig::Statement
  def self.tokenize_path(path, &error_block)
    tokenizer = Fig::StringTokenizer.new TOKENIZING_SUBEXPRESSION_MATCHER, '\\['
    return tokenizer.tokenize path, &error_block
  end

  attr_reader :variable
  attr_reader :tokenized_path

  def initialize(line_column, source_description, variable, tokenized_path)
    super(line_column, source_description)

    @variable       = variable
    @tokenized_path = tokenized_path

    path = tokenized_path.to_escaped_string
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

  def statement_type()
    return 'retrieve'
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

  def deparse_as_version(deparser)
    return deparser.retrieve(self)
  end

  def minimum_grammar_for_emitting_input()
    return minimum_grammar()
  end

  def minimum_grammar_for_publishing()
    return minimum_grammar()
  end

  private

  def minimum_grammar()
    path = tokenized_path.to_escaped_string
    if path =~ /\s/
      return [1, 'contains whitespace']
    end

    # Can't have octothorpes anywhere in v0 due to comment stripping via
    # regex.
    if path =~ /#/
      return [1, 'contains a comment ("#") character']
    end

    if path =~ %r< ' >x
      return [1, %Q<contains a single quote character>]
    end

    if path =~ %r< " >x
      return [1, %Q<contains a double quote character>]
    end

    if path =~ %r< ( [^a-zA-Z0-9_/.\[\]-] ) >x
      return [1, %Q<contains a "#{$1}" character>]
    end

    return [0]
  end

  TOKENIZING_SUBEXPRESSION_MATCHER = [
    {
      # Shortest sequence of characters that starts with an open square bracket
      # and ends with either a close square bracket or end of string.
      :pattern => %r< \[ [^\]]* \]? >x,
      :action  =>
        lambda {
          |subexpression, error_block|

          if subexpression == '[package]'
            return Fig::TokenizedString::Token.new :package_path, '[package]'
          end

          error_block.call \
            %q<contains an unescaped "[" that is not followed by "ackage]".>
          return
        }
    }
  ]
end
