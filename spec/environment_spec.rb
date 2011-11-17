require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environment'
require 'fig/package'

def new_example_environment()
  environment = Fig::Environment.new(nil, nil, {'FOO' => 'bar'}, nil)

  %w< one two three >.each do
    |package_name|
    environment.register_package(
      Fig::Package.new(
        package_name,
        "#{package_name}-version",
        "#{package_name}-directory",
        []
      )
    )
  end

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

  describe 'package name substitution in commands' do
    it 'can replace bare names' do
      substituted_command = substitute_command %w< @one >

      substituted_command.should == %w< one-directory >
    end

    it 'can replace prefixed names' do
      substituted_command = substitute_command %w< something@one >

      substituted_command.should == %w< somethingone-directory >
    end

    it 'can replace multiple names in a single argument' do
      substituted_command = substitute_command %w< @one@two@three >

      substituted_command.should == %w< one-directorytwo-directorythree-directory >
    end

    it 'can replace names in multiple arguments' do
      substituted_command = substitute_command %w< @one @two >

      substituted_command.should == %w< one-directory two-directory >
    end

    it 'can handle simple escaped names' do
      substituted_command = substitute_command %w< \@one\@two >

      substituted_command.should == %w< @one@two >
    end

    it 'can handle escaped backslash' do
      substituted_command = substitute_command %w< bar\\\\foo >

      substituted_command.should == %w< bar\\foo >
    end

    it 'can handle escaped backslash in front of @' do
      substituted_command = substitute_command %w< bar\\\\@one >

      substituted_command.should == %w< bar\\one-directory >
    end

    it 'can handle escaped backslash in front of escaped @' do
      substituted_command = substitute_command %w< bar\\\\\\@one >

      substituted_command.should == %w< bar\\@one >
    end

    it 'complains about unknown escapes' do
      expect {
        # Grrr, Ruby syntax: that's three backslashes followed by "f"
        substitute_command %w< bar\\\\\\foo >
      }.to raise_error(/unknown escape/i)
    end
  end
end
