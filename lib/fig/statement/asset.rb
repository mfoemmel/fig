require 'fig/statement'
require 'fig/string_tokenizer'
require 'fig/url'

module Fig; end
class Fig::Statement; end

# Some sort of file to be included in a package.
module Fig::Statement::Asset
  attr_reader :location

  def self.included(class_included_into)
    class_included_into.extend(ClassMethods)

    return
  end

  def glob_if_not_url?()
    return @glob_if_not_url
  end

  def urls()
    return [location()]
  end

  def is_asset?()
    return true
  end

  def requires_globbing?()
    return glob_if_not_url? && ! Fig::URL.is_url?(location())
  end

  def standard_asset_name()
    # Not so hot of an idea if the location is a URL and has query parameters
    # in it, but not going to fix this now.
    basename = location().split('/').last

    if Fig::URL.is_url? location
      return CGI.unescape basename
    end

    return basename
  end

  def minimum_grammar_for_emitting_input()
    return minimum_grammar_for_value location
  end

  def minimum_grammar_for_publishing()
    return minimum_grammar_for_value asset_name
  end

  private

  def minimum_grammar_for_value(value)
    return [0] if value.nil?

    if value =~ /\s/
      return [1, 'contains whitespace']
    end

    # Can't have octothorpes anywhere in v0 due to comment stripping via
    # regex.
    if value =~ /#/
      return [1, 'contains a "#" character']
    end

    if ! glob_if_not_url? && value =~ / ( [*?\[\]{}] ) /x
      return [
        1, %Q<contains a glob character ("#{$1}") which should not be globbed>
      ]
    end

    if value =~ / ( ["'<>|] ) /x
      return [1, %Q<contains a "#{$1}" character>]
    end

    return [0]
  end

  module ClassMethods
    def validate_and_process_escapes_in_location(location, &block)
      tokenizer = Fig::StringTokenizer.new
      tokenized_string = tokenizer.tokenize(location, &block)
      return if ! tokenized_string

      # "config" is a reasonable asset name, so we let that pass.
      if Fig::Statement.strict_keyword?(tokenized_string.to_expanded_string)
        yield 'is a keyword.'
      end

      return tokenized_string
    end
  end
end
