require 'fig/repository'
require 'fig/statement'
require 'fig/statement/asset'

module Fig; end

# Specifies a file (possibly via a URL) that is part of the current package.
#
# Differs from an Archive in that the contents will not be extracted.
class Fig::Statement::Resource < Fig::Statement
  include Fig::Statement::Asset

  def initialize(line_column, source_description, url, glob)
    super(line_column, source_description)

    @url  = url
    @glob = glob
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
    quote = glob? ? %q<"> : %q<'>

    # TODO: fix backslash escape bug.
    %Q<#{indent}resource #{quote}#{url}#{quote}>
  end
end
