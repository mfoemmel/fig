require 'fig/statement'
require 'fig/statement/asset'
require 'fig/url'

module Fig; end
class  Fig::Statement; end

# Specifies a file (possibly via a URL) that is part of the current package.
#
# Differs from an Archive in that the contents will not be extracted.
class Fig::Statement::Resource < Fig::Statement
  include Fig::Statement::Asset

  def initialize(line_column, source_description, url, glob_if_not_url)
    super(line_column, source_description)

    @url             = url
    @glob_if_not_url = glob_if_not_url
  end

  def asset_name()
    if Fig::URL.is_url?(url())
      return standard_asset_name()
    end

    # This resource will end up being bundled with others and will not live in
    # the package by itself.
    return nil
  end

  def unparse(indent)
    return unparse_asset(indent, 'resource')
  end
end
