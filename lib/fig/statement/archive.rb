require 'fig/statement'
require 'fig/statement/asset'

module Fig; end

# Specifies an archive file (possibly via a URL) that is part of the current package.
#
# Differs from a Resource in that the contents will be extracted.
class Fig::Statement::Archive < Fig::Statement
  include Fig::Statement::Asset

  attr_reader :url

  def initialize(line_column, url)
    super(line_column)

    @url = url
  end

  def asset_name()
    return standard_asset_name()
  end

  def unparse(indent)
    %Q<#{indent}archive "#{url}">
  end
end
