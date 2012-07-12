require 'fig/parser'
require 'fig/statement'
require 'fig/url'

module Fig; end
class Fig::Statement; end

# Some sort of file to be included in a package.
module Fig::Statement::Asset
  attr_reader :url

  def self.included(class_included_into)
    class_included_into.extend(ClassMethods)

    return
  end

  def glob_if_not_url?()
    return @glob_if_not_url
  end

  def urls()
    return [ url() ]
  end

  def is_asset?()
    return true
  end

  def requires_globbing?()
    return glob_if_not_url? && ! Fig::URL.is_url?(url())
  end

  def standard_asset_name()
    # Not so hot of an idea if the URL has query parameters in it, but not
    # going to fix this now.
    return url().split('/').last()
  end

  def minimum_grammar_version_required()
    return 1 if url =~ /\s/

    # Can't have octothorpes anywhere in v0 due to comment stripping via regex.
    return 1 if url =~ /#/

    # If we shouldn't glob, but we've got glob characters...
    return 1 if ! glob_if_not_url? && url =~ /[*?\[\]{}]/

    return 0
  end

  private

  def unparse_asset(indent, keyword)
    quote       = %q<'>
    escaped_url = url

    if escaped_url !~ /\s/
      # TODO: ugly hack to get an immediate-term set of passing tests.
      quote = escaped_url =~ /[*?\[\]{}]/ ? '' : %q<">
    elsif glob_if_not_url?
      quote = %q<">
      escaped_url = url.gsub(/\\/, '\\\\')
    end

    return %Q<#{indent}#{keyword} #{quote}#{escaped_url}#{quote}>
  end

  module ClassMethods
    # Modifies the parameter to deal with quoting, escaping.
    def validate_and_process_escapes_in_url!(url, &block)
      was_in_single_quotes =
        Fig::Statement.strip_quotes_and_process_escapes!(url, &block)
      return if was_in_single_quotes.nil?

      if url.include? '@'
        yield %q<contains an "@", which isn't permitted in order to allow for package substitution.>
        return
      end

      if url =~ / ( ["<>|] ) /x
        yield %Q<contains a "#{$1}", which isn't permitted because Windows doesn't allow it in file names.>
        return
      end

      if url =~ / ( ' ) /x
        yield %Q<contains a "#{$1}", which isn't permitted to allow for future grammar expansion.>
        return
      end

      # "config" is a reasonable asset name, so we let that pass.
      if Fig::Parser.strict_keyword?(url)
        yield 'is a keyword.'
      end

      return ! was_in_single_quotes
    end
  end
end
