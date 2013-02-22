require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/command'
require 'fig/statement/configuration'
require 'fig/statement/include'
require 'fig/statement/override'
require 'fig/statement/path'
require 'fig/statement/set'
require 'fig/statement/synthetic_raw_text'

describe 'Statement::Configuration' do
  it 'moves override statements to the front of the set of statements' do
    override_c = Fig::Statement::Override.new(nil, nil, 'C', 'version')
    override_b = Fig::Statement::Override.new(nil, nil, 'B', 'version')
    override_a = Fig::Statement::Override.new(nil, nil, 'A', 'version')

    command = Fig::Statement::Command.new(nil, nil, %w< something to run >)
    incorporate = Fig::Statement::Include.new(nil, nil, nil, nil, nil)

    parsed_name, parsed_value =
      Fig::Statement::Path.parse_name_value 'name=value'
    path = Fig::Statement::Path.new(nil, nil, parsed_name, parsed_value)
    set = Fig::Statement::Set.new(nil, nil, parsed_name, parsed_value)

    config = Fig::Statement::Configuration.new(
      nil,
      nil,
      'name',
      [command, override_c, incorporate, override_b, path, override_a, set]
    )

    statements_to_be_checked =
      config.statements.reject {
        |statement| statement.is_a? Fig::Statement::SyntheticRawText
      }
    statements_to_be_checked.should ==
      [override_c, override_b, override_a, command, incorporate, path, set]
  end
end
