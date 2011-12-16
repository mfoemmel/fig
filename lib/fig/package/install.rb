require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# This class appears to be unused, though it is in the grammar.
class Fig::Package::Install
  include Fig::Package::Statement

  def initialize(statements)
    @statements = statements
  end

  def unparse(indent)
    prefix = "\n#{indent}install"
    body = @statements.map { |statement| statement.unparse(indent+'  ') }.join("\n")
    suffix = "#{indent}end"
    return [prefix, body, suffix].join("\n")
  end
end
