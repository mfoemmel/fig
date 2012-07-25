module Fig; end

module Fig::Unparser
  def unparse(statements)
    @text         = ''
    @indent_level = @initial_indent_level

    statements.each { |statement| statement.unparse_as_version(self) }

    text          = @text
    @text         = nil
    @indent_level = nil

    return text
  end

  def archive(statement)
    asset 'archive', statement

    return
  end

  def command(statement)
    raise NotImplementedError
  end

  def configuration(configuration_statement)
    if ! @text.empty?
      @text << "\n"
    end

    add_indent
    @text << 'config '
    @text << configuration_statement.name
    @text << "\n"

    @indent_level += 1
    begin
      configuration_statement.statements.each do
        |statement|

        statement.unparse_as_version(self)
      end
    ensure
      @indent_level -= 1
    end

    add_indent
    @text << "end\n"

    return
  end

  def grammar_version(statement)
    raise NotImplementedError
  end

  def include(statement)
    add_indent

    @text << 'include '
    @text << Fig::PackageDescriptor.format(
      statement.package_name, statement.version, statement.config_name
    )
    @text << "\n"

    return
  end

  def override(statement)
    add_indent

    @text << 'override '
    @text << Fig::PackageDescriptor.format(
      statement.package_name, statement.version, nil
    )
    @text << "\n"

    return
  end

  def path(statement)
    environment_variable(statement, 'append')

    return
  end

  def resource(statement)
    asset 'resource', statement

    return
  end

  def retrieve(statement)
    raise NotImplementedError
  end

  def set(statement)
    environment_variable(statement, 'set')

    return
  end

  private

  def asset(keyword, statement)
    raise NotImplementedError
  end

  def asset_path(statement)
    if @emit_as_input_or_to_be_published_values == :emit_as_input
      return statement.url
    end

    return statement.asset_name
  end

  def environment_variable(statement, keyword)
    raise NotImplementedError
  end

  def add_indent()
    @text << @indent_string * @indent_level

    return
  end
end
