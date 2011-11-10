require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Command
  attr_reader :command

  def initialize(command)
    @command = command
  end

  def unparse(indent)
    %Q<#{indent}command "#{@command}">
  end
end
