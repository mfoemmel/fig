require 'fig/statement'

module Fig; end

# Specifies an archive file (possibly via a URL) that is part of the current package.
#
# Differs from a Resource in that the contents will be extracted.
class Fig::Statement::Archive < Fig::Statement
  attr_reader :url

  def initialize(line, column, url)
    super(line, column)

    @url = url
  end

  def urls
    return [@url]
  end

  def unparse(indent)
    %Q<#{indent}archive "#{url}">
  end
end
