require 'fig/parser'

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

  def standard_asset_name()
    # Not so hot of an idea if the URL has query parameters in it, but not
    # going to fix this now.
    return url().split('/').last()
  end

  private

  def unparse_asset(indent, keyword)
    quote = glob_if_not_url? ? %q<"> : %q<'>

    # TODO: fix backslash escape bug.
    return %Q<#{indent}#{keyword} #{quote}#{url}#{quote}>
  end

  module ClassMethods
    # Modifies the parameter to deal with quoting, escaping.
    #
    # Unquoted:      globbing, but no escapes
    # Double quoted: globbing, with potential future escapes other than \\
    # Single quoted: no globbing, no escapes
    def validate_and_process_escapes_in_url(url, &block)
      need_to_glob = true
      replaced_quotes = validate_url_double_quotes(url, &block)
      return if replaced_quotes.nil?
      if ! replaced_quotes
        replaced_quotes = validate_url_single_quotes(url, &block)
        return if replaced_quotes.nil?
        need_to_glob = ! replaced_quotes
      end

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

      return need_to_glob
    end

    private

    def validate_url_double_quotes(url)
      # Damn you Ruby 1.8 for returning an integer from string[number]!!!!
      return false if url[0..0] != %q<"> && url[-1..-1] != %q<">

      if url.length < 2 || url[0..0] != %q<"> || url[-1..-1] != %q<">
        yield 'has unbalanced double quotes.'
        return
      end

      # Is there a simpler way to do strip the quotes?
      url.sub!(/\A " (.*) " \z/xs, '\1')

      if url =~ %r<
        (?: ^ | [^\\])      # Start of line or non backslash
        (?: \\{2})*         # Even number of backslashes (including 0)
        (
          \\                # One more blackslash
          (?: [^\\] | \z )  # A non-backslash or end of string
        )
      >xs
        yield "contains a bad escape sequence (#{$1})."
        return
      end

      url.gsub!(%r< \\{2} >xs, '\\')

      return true
    end

    def validate_url_single_quotes(url)
      return false if url[0..0] != %q<'> && url[-1..-1] != %q<'>

      if url.length < 2 || url[0..0] != %q<'> || url[-1..-1] != %q<'>
        yield 'has unbalanced single quotes.'
        return
      end

      url.sub!(/\A ' (.*) ' \z/xs, '\1')

      return true
    end
  end
end
