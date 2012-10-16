require 'fig/statement'
require 'fig/string_tokenizer'
require 'fig/tokenized_string/token'

module Fig; end
class Fig::Statement; end

# A statement that manipulates an environment variable.
module Fig::Statement::EnvironmentVariable
  attr_reader :name, :tokenized_value

  def self.included(class_included_into)
    class_included_into.extend(ClassMethods)

    return
  end

  def minimum_grammar_for_emitting_input()
    return minimum_grammar()
  end

  def minimum_grammar_for_publishing()
    return minimum_grammar()
  end

  private

  def standard_minimum_grammar()
    value = tokenized_value.to_escaped_string
    if value =~ /\s/
      return [1, 'contains whitespace']
    end

    # Can't have octothorpes anywhere in v0 due to comment stripping via
    # regex.
    if value =~ /#/
      return [1, 'contains a comment ("#") character']
    end

    if value =~ / ( ["'] ) /x
      return [1, %Q<contains a "#{$1}" character>]
    end

    return [0]
  end

  module ClassMethods
    def seperate_name_and_value(combined, &error_block)
      variable, raw_value = combined.split '=', 2
      if variable !~ Fig::Statement::ENVIRONMENT_VARIABLE_NAME_REGEX
        yield \
          %Q<"#{variable}" does not consist solely of alphanumerics and underscores.>
        return
      end

      return [variable, raw_value || '']
    end

    def tokenize_value(value, &error_block)
      tokenizer = Fig::StringTokenizer.new TOKENIZING_SUBEXPRESSION_MATCHER, '@'
      return tokenizer.tokenize value, &error_block
    end

    # TODO: Test coverage doesn't appear to be running this.
    def base_v0_value_validation(variable, raw_value)
      if raw_value =~ /\s/
        yield %Q<The value of #{variable} (#{raw_value}) contains whitespace.>
        return
      end
      if raw_value =~ /'/
        yield %Q<The value of #{variable} (#{raw_value}) contains a single quote.>
        return
      end
      if raw_value =~ /"/
        yield %Q<The value of #{variable} (#{raw_value}) contains a double quote.>
        return
      end

      return
    end

    private

    TOKENIZING_SUBEXPRESSION_MATCHER = [
      {
        :pattern => %r<\@>,
        :action =>
          lambda {
            |subexpression, error_block|

            Fig::TokenizedString::Token.new :package_path, '@'
          }
      }
    ]
  end
end
