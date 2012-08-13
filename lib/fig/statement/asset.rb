require 'cgi'

require 'fig/parser'
require 'fig/statement'
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
    return 0 if value.nil?
    return 2 if value =~ /\s/

    # Can't have octothorpes anywhere in v0 due to comment stripping via regex.
    return 2 if value =~ /#/

    # If we shouldn't glob, but we've got glob characters...
    return 2 if ! glob_if_not_url? && value =~ /[*?\[\]{}]/

    return 0
  end

  module ClassMethods
    # Modifies the parameter to deal with quoting, escaping.
    def validate_and_process_escapes_in_location!(location, &block)
      was_in_single_quotes =
        Fig::Statement.strip_quotes_and_process_escapes!(location, &block)
      return if was_in_single_quotes.nil?

      if location.include? '@'
        yield %q<contains an "@", which isn't permitted in order to allow for package substitution.>
        return
      end

      if location =~ / ( ["<>|] ) /x
        yield %Q<contains a "#{$1}", which isn't permitted because Windows doesn't allow it in file names.>
        return
      end

      if location =~ / ( ' ) /x
        yield %Q<contains a "#{$1}", which isn't permitted to allow for future grammar expansion.>
        return
      end

      # "config" is a reasonable asset name, so we let that pass.
      if Fig::Parser.strict_keyword?(location)
        yield 'is a keyword.'
      end

      return ! was_in_single_quotes
    end
  end
end
