require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environmentvariables/caseinsensitive'
require 'fig/environmentvariables/casesensitive'

def find_diffs(primary_hash, secondary_hash, diff_hash)
  primary_hash.each do |key, value|
    if ! secondary_hash.has_key?(key)
      diff_hash[key] = value
    elsif primary_hash[key] != secondary_hash[key]
      diff_hash[key] = value
    end
  end

  return
end

def hash_differences(hash_one, hash_two)
  hash_differences = {}
  find_diffs(hash_one, hash_two, hash_differences)
  find_diffs(hash_two, hash_one, hash_differences)

  return hash_differences
end

describe 'EnvironmentVariables' do
  it 'correctly sets and unsets the system environment variables' do
    env_vars = Fig::EnvironmentVariables::CaseSensitive.new({ 'Foo' => 'BAR' })

    sys_vars_prior = {}
    sys_vars_prior.merge!(ENV.to_hash)
    sys_vars_set = {}
    sys_vars_after = {}

    env_vars['FOO'] = 'BAR'
    env_vars.with_environment { sys_vars_set.merge!(ENV.to_hash) }
    sys_vars_after.merge!(ENV.to_hash)

    hash_differences(sys_vars_prior, sys_vars_after).should be_empty
    before_and_during_diff = hash_differences(sys_vars_prior, sys_vars_set)
    hash_differences(before_and_during_diff, {'FOO' => 'BAR', 'Foo' => 'BAR'}).should be_empty
  end

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
