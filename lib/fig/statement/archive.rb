require 'fig/statement'
require 'fig/statement/asset'

module Fig; end

# Specifies an archive file (possibly via a URL) that is part of a package.
#
# Differs from a Resource in that the contents will be extracted.
class Fig::Statement::Archive < Fig::Statement
  include Fig::Statement::Asset

  attr_reader :url

  def initialize(line_column, source_description, url, glob_if_not_url)
    super(line_column, source_description)

    @url             = url
    @glob_if_not_url = glob_if_not_url
  end

  def asset_name()
    return standard_asset_name()
  end

  def unparse(indent)
    return unparse_asset(indent, 'archive')
  end
end
