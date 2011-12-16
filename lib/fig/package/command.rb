require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# Specifies a default command that will be executed for a given Configuration
# if no command is specified on the command-line.
class Fig::Package::Command
  include Fig::Package::Statement

  attr_reader :command

  def initialize(command)
    @command = command
  end

  def unparse(indent)
    %Q<#{indent}command "#{@command}">
  end
end
