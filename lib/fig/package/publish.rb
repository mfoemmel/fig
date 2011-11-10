require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Publish
  attr_reader :local_name, :remote_name

  def initialize(local_name, remote_name)
    @local_name = local_name
    @remote_name = remote_name
  end

  def unparse(indent)
    "#{indent}publish #{@local_name}->#{@remote_name}"
  end
end
