require 'fig/statement'

module Fig; end

# Specifies a file (possibly via a URL) that is part of the current package.
#
# Differs from an Archive in that the contents will not be extracted.
class Fig::Statement::Resource < Fig::Statement
  attr_reader :url

  def initialize(line, column, url)
    super(line, column)

    @url = url
  end

  def urls
    return [@url]
  end

  def unparse(indent)
    "#{indent}resource #{url}"
  end
end
