require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environment'
require 'fig/package'

def new_example_environment()
  environment = Fig::Environment.new(nil, nil, {'FOO' => 'bar'}, nil)
  environment.register_package(
    Fig::Package.new('foo', 'version', 'directory', [])
  )

  return environment
end

def substitute_command(command)
  environment = new_example_environment

  substituted_command = nil
  environment.execute_shell(command) {
    |command_line|
    substituted_command = command_line
  }

  return substituted_command
end

describe 'Environment' do
  it 'can hand back a variable' do
    environment = new_example_environment

    environment['FOO'].should == 'bar'
  end

  it 'can replace bare package names in the command' do
    substituted_command = substitute_command %w< @foo >

    substituted_command.should == %w< directory >
  end

  it 'can replace prefixed package names in the command' do
    substituted_command = substitute_command %w< something@foo >

    substituted_command.should == %w< somethingdirectory >
  end
end
