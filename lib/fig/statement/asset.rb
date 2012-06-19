require 'fig/parser'

module Fig; end
class Fig::Statement; end

# Some sort of file to be included in a package.
module Fig::Statement::Asset
  def self.included(class_included_into)
    class_included_into.extend(ClassMethods)

    return
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

  module ClassMethods
    def validate_url(url)
      # "config" is a reasonable asset name, so we let that pass.
      if Fig::Parser.strict_keyword?(url)
        yield 'is a keyword.'
      end

      return
    end
  end
end
