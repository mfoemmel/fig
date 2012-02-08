require 'fig/statement'

module Fig; end

# Artificial statement (it's not in the grammar) used to handle default
# publishing.
class Fig::Statement::Publish
  include Fig::Statement

  def unparse(indent)
    "#{indent}publish"
  end
end
