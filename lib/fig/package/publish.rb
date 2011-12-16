require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# Artificial statement (it's not in the grammar) used to handle default
# publishing.
class Fig::Package::Publish
  include Fig::Package::Statement

  attr_reader :local_name, :remote_name

  def initialize(local_name, remote_name)
    @local_name = local_name
    @remote_name = remote_name
  end

  def unparse(indent)
    "#{indent}publish #{@local_name}->#{@remote_name}"
  end
end
