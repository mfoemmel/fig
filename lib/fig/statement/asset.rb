require 'fig/parser'

module Fig; end
class Fig::Statement; end

# Some sort of file to be included in a package.
module Fig::Statement::Asset
  def self.included(class_included_into)
    class_included_into.extend(ClassMethods)

    return
  end

  def glob?()
    return @glob
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

  def set_up_url(url)
    if url[0] == '"'
      @url = url[1..-2]
      @glob = true
    else
      @url = url
      @glob = false
    end

    return
  end

  module ClassMethods
    def validate_url(url)
      if url[0] == '"' && url[-1] != '"' || url[0] != '"' && url[-1] == '"'
        yield 'has unbalanced quotes.'
        return
      end

      if url[0] == '"'
        if url.length < 3
          yield 'is empty'
          return
        end

        url = url[1..-2]
      end

      if url.include? '@'
        yield %q<contains an "@", which isn't permitted in order to allow for package substitution.>
        return
      end

      if url =~ / ( ["<>|] ) /x
        yield %Q<contains a "#{$1}", which isn't permitted because Windows doesn't allow it in file names.>
        return
      end

      if url =~ / \s /x
        # We may need to allow a space character in the future, but this will
        # require a change to the grammar.
        yield %q<contains whitespace.>
        return
      end

      # "config" is a reasonable asset name, so we let that pass.
      if Fig::Parser.strict_keyword?(url)
        yield 'is a keyword.'
      end

      return
    end
  end
end
