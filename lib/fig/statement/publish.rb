require 'fig/statement'

module Fig; end

# Artificial statement (it's not in the grammar) used to handle default
# publishing.
class Fig::Statement::Publish < Fig::Statement
  def initialize()
    super(nil, nil)
  end

  def unparse(indent)
    "#{indent}publish"
  end
end
