require 'fig/repository'
require 'fig/statement'
require 'fig/statement/asset'

module Fig; end

# Specifies a file (possibly via a URL) that is part of the current package.
#
# Differs from an Archive in that the contents will not be extracted.
class Fig::Statement::Resource < Fig::Statement
  include Fig::Statement::Asset

  attr_reader :url

  def initialize(line_column, url)
    super(line_column)

    @url = url
  end

  def asset_name()
    if Fig::Repository.is_url?(url())
      return standard_asset_name()
    end

    # This resource will end up being bundled with others and will not live in
    # the package by itself.
    return nil
  end

  def unparse(indent)
    "#{indent}resource #{url}"
  end
end
