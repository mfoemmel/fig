require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/include'
require 'fig/statement/override'
require 'fig/statement/path'
require 'fig/statement/set'

describe 'Fig::Statement::Configuration' do
  it 'moves override statements to the front of the set of statements' do
    override_c = Fig::Statement::Override.new(nil, nil, 'C', 'version')
    override_b = Fig::Statement::Override.new(nil, nil, 'B', 'version')
    override_a = Fig::Statement::Override.new(nil, nil, 'A', 'version')

    command = Fig::Statement::Command.new(nil, nil, %w< something to run >)
    incorporate = Fig::Statement::Include.new(nil, nil, nil, nil)
    path = Fig::Statement::Path.new(nil, nil, 'name', 'value')
    set = Fig::Statement::Set.new(nil, nil, 'name', 'value')

    config = Fig::Statement::Configuration.new(
      nil,
      nil,
      'name',
      [command, override_c, incorporate, override_b, path, override_a, set]
    )

    config.statements.should ==
      [override_c, override_b, override_a, command, incorporate, path, set]
  end
end
