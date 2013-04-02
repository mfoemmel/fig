require 'fig/statement'
require 'fig/statement/asset'

module Fig; end
class  Fig::Statement; end

# Specifies an archive file (possibly via a URL) that is part of a package.
#
# Differs from a Resource in that the contents will be extracted.
class Fig::Statement::Archive < Fig::Statement
  include Fig::Statement::Asset

  def initialize(line_column, source_description, location, glob_if_not_url)
    super(line_column, source_description)

    @location        = location
    @glob_if_not_url = glob_if_not_url
  end

  def statement_type()
    return 'archive'
  end

  def asset_name()
    return standard_asset_name()
  end

  def deparse_as_version(deparser)
    return deparser.archive(self)
  end
end
