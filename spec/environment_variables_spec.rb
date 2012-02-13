require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environmentvariables'

describe 'EnvironmentVariables' do
  it 'sets and retrieves the fig environment variables on windows regardless of case on windows' do
    env_vars = Fig::EnvironmentVariables.new(true, { 'Foo' => 'BAR' })

    env_vars['FOO'].should == 'BAR'
    env_vars['foo'].should == 'BAR'

    env_vars['BAR'] = 'BAZ'
    env_vars['BAR'].should == 'BAZ'
    env_vars['bar'].should == 'BAZ'
  end

  it 'sets and retrieves the fig environment variables on nix in a case sensitive manner' do
    env_vars = Fig::EnvironmentVariables.new(false, { 'Foo' => 'BAR' })

    env_vars['FOO'].should == nil
    env_vars['Foo'].should == 'BAR'

    env_vars['BAR'] = 'BAZ'
    env_vars['BAR'].should == 'BAZ'
    env_vars['bar'].should == nil
  end

  it 'appends values to the fig environment variables on a nix platform' do
    env_vars = Fig::EnvironmentVariables.new(false, { 'Foo' => 'BAR' })

    env_vars.append_variable('Foo', 'BAZ')
    env_vars['Foo'].should == 'BAZ' + File::PATH_SEPARATOR + 'BAR'

    env_vars.append_variable('FOO', 'XYZZY')
    env_vars['FOO'].should == 'XYZZY'
  end

  it 'appends values to the fig environment variables on a windows platform' do
    env_vars = Fig::EnvironmentVariables.new(true, { 'Foo' => 'BAR' })

    env_vars.append_variable('Foo', 'BAZ')
    env_vars['Foo'].should == 'BAZ' + File::PATH_SEPARATOR + 'BAR'

    env_vars.append_variable('FOO', 'XYZZY')
    env_vars['Foo'].should == 'XYZZY' + File::PATH_SEPARATOR + 'BAZ' + File::PATH_SEPARATOR + 'BAR'
  end
end
