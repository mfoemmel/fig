require 'cgi'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListVariablesAsGraphviz
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
    style = ''
    color = ''
    if package == @execution_context.base_package
      if base_display_config_names.include?(config_name)
        style = ' style = "rounded, bold"'
      end
      if config_name == @execution_context.base_config
        color = ' color = blue'
      end
    end

    name = node_name package, config_name
    rows = variable_statement_rows package, config_name
    label = nil
    if rows.empty?
      label = %Q<"#{name}">
    else
      label = %Q[<<table border="0"><tr><td border="0" colspan="3"><b>#{name}</b></td></tr>#{rows}</table>>]
    end

    return %Q<"#{name}" [label = #{label}#{style}#{color}];>
  end

  def variable_statement_rows(package, config_name)
    string = ''

    package[config_name].walk_statements do
      |statement|

      if statement.is_environment_variable?
        string << format_variable_statement(statement)
      end
    end

    return string
  end

  def format_variable_statement(statement)
    string = '<tr><td align="right">'
    string << statement.statement_type
    string << '</td><td align="left">$'
    string << CGI.escape_html(statement.name)
    string << '</td><td align="left">'
    string << CGI.escape_html(statement.tokenized_value.to_escaped_string)
    string << '</td></tr>'

    return string
  end
end
