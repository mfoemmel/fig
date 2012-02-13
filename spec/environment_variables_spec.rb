require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environmentvariables/caseinsensitive'
require 'fig/environmentvariables/casesensitive'

describe 'EnvironmentVariables' do
  describe 'case sensitive' do
    it 'sets and retrieves variables' do
      env_vars = Fig::EnvironmentVariables::CaseSensitive.new({ 'Foo' => 'BAR' })

      env_vars['FOO'].should == nil
      env_vars['Foo'].should == 'BAR'

      env_vars['BAR'] = 'BAZ'
      env_vars['BAR'].should == 'BAZ'
      env_vars['bar'].should == nil
    end

    it 'prepends values onto variables' do
      env_vars = Fig::EnvironmentVariables::CaseSensitive.new({ 'Foo' => 'BAR' })

      env_vars.prepend_variable('Foo', 'BAZ')
      env_vars['Foo'].should == 'BAZ' + File::PATH_SEPARATOR + 'BAR'

      env_vars.prepend_variable('FOO', 'XYZZY')
      env_vars['FOO'].should == 'XYZZY'
    end
  end

  describe 'case sensitive' do
    it 'sets and retrieves variables' do
      env_vars = Fig::EnvironmentVariables::CaseInsensitive.new({ 'Foo' => 'BAR' })

      env_vars['FOO'].should == 'BAR'
      env_vars['foo'].should == 'BAR'

      env_vars['BAR'] = 'BAZ'
      env_vars['BAR'].should == 'BAZ'
      env_vars['bar'].should == 'BAZ'
    end

    it 'prepends values onto variables' do
      env_vars = Fig::EnvironmentVariables::CaseInsensitive.new({ 'Foo' => 'BAR' })

      env_vars.prepend_variable('Foo', 'BAZ')
      env_vars['Foo'].should == 'BAZ' + File::PATH_SEPARATOR + 'BAR'

      env_vars.prepend_variable('FOO', 'XYZZY')
      env_vars['Foo'].should == 'XYZZY' + File::PATH_SEPARATOR + 'BAZ' + File::PATH_SEPARATOR + 'BAR'
    end
  end
end
