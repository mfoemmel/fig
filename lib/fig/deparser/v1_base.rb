# coding: utf-8

module Fig; end
module Fig::Deparser; end

# Handles serializing of statements in the v1 grammar.
module Fig::Deparser::V1Base
  def command(statement)
    add_indent
    @text << %Q<command\n>

    add_indent(@indent_level + 1)
    statement.command.each do
      |argument|

      emit_tokenized_value argument
      @text << ' '
    end

    @text << %Q<\n>
    add_indent
    @text << %Q<end\n>

    return
  end

  def retrieve(statement)
    add_indent

    @text << 'retrieve '
    @text << statement.variable
    @text << '->'

    emit_tokenized_value statement.tokenized_path

    @text << "\n"

    return
  end

  private

  def asset(keyword, statement)
    quote = statement.glob_if_not_url? ? %q<"> : %q<'>
    path  =
      asset_path(statement).gsub('\\', ('\\' * 4)).gsub(quote, "\\\\#{quote}")

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

    emit_tokenized_value statement.tokenized_value

    @text << "\n"

    return
  end

  def emit_tokenized_value(tokenized_value)
    if tokenized_value.can_be_single_quoted?
      @text << %q<'>
      @text << tokenized_value.to_single_quoted_string
      @text << %q<'>
    else
      @text << %q<">
      @text << tokenized_value.to_escaped_string
      @text << %q<">
    end

    return
  end
end
