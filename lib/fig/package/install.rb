require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Install
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
