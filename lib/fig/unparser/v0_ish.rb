module Fig; end
module Fig::Unparser; end

module Fig::Unparser::V0Ish
  def command(statement)
    add_indent

    @text << %q<command ">
    @text << statement.command
    @text << %Q<"\n>

    return
  end

  def retrieve(statement)
    add_indent

    @text << 'retrieve '
    @text << statement.var
    @text << '->'
    @text << statement.path
    @text << "\n"

    return
  end

  private

  def asset(keyword, statement)
    path  = asset_path statement
    quote = path =~ /[*?\[\]{}]/ ? '' : %q<">

    add_indent
    @text << keyword
    @text << ' '
    @text << quote
    @text << path
    @text << quote
    @text << "\n"

    return
  end

  def environment_variable(statement, keyword)
    add_indent

    @text << keyword
    @text << ' '
    @text << statement.name
    @text << '='
    @text << statement.value
    @text << "\n"

    return
  end
end
