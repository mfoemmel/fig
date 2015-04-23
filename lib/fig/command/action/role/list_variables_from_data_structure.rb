# coding: utf-8

require 'cgi'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListVariablesFromDataStructure
  def descriptor_requirement()
    return nil
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return nil # don't care
  end

  def apply_config?()
    return nil # don't care
  end

  private

  def node_content(package, config_name)
    hash       = new_package_config_hash package, config_name
    statements = variable_statements package, config_name
    if not statements.empty?
      hash['variables'] = statements
    end

    return hash
  end

  def variable_statements(package, config_name)
    statements = []

    package[config_name].walk_statements do
      |statement|

      if statement.is_environment_variable?
        statements << hash_for_variable_statement(statement)
      end
    end

    return statements
  end

  def hash_for_variable_statement(statement)
    return {
      'type'  => statement.statement_type,
      'name'  => statement.name,
      'value' => statement.tokenized_value.to_escaped_string,
    }
  end
end
