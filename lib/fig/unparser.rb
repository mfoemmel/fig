module Fig; end

module Fig::Unparser
  # Determine the class of Unparser necessary for a set of Statements; the
  # parameter can be a single statement or multiple.  Returns both the class
  # and a list of explanations of why the class was picked.
  def self.class_for_statements(
    statements, emit_as_input_or_to_be_published_values
  )
    # Note: we very specifically do not require the files containing the
    # Unparser classes in order to avoid circular dependencies.
    statements = [statements].flatten

    versions =
      self.gather_versions statements, emit_as_input_or_to_be_published_values
    version = (versions.map {|version_info| version_info[0]}).max || 0
    explanations = (versions.collect {|v| v[1]}).reject {|e| e.nil?}

    case version
    when 0
      return Fig::Unparser::V0, explanations
    when 1
      return Fig::Unparser::V1, explanations
    end

    # TODO: Until v2 grammar handling is done, ensure we don't emit anything
    # old fig versions cannot handle.
    if ! ENV['FIG_ALLOW_NON_V0_GRAMMAR']
      raise 'Reached a point where something could not be represented by the v0 grammar. Bailing out.'
    end

    return Fig::Unparser::V2, explanations
  end

  def self.determine_version_and_unparse(
    statements, emit_as_input_or_to_be_published_values
  )
    unparser_class, explanations = self.class_for_statements(
      statements, emit_as_input_or_to_be_published_values
    )
    unparser = unparser_class.new emit_as_input_or_to_be_published_values

    return (unparser.unparse [statements].flatten), explanations
  end

  private

  def self.gather_versions(statements, emit_as_input_or_to_be_published_values)
    if emit_as_input_or_to_be_published_values == :emit_as_input
      return statements.map {
        |statement|

        self.expand_version_and_explanation(
          statement, statement.minimum_grammar_for_emitting_input
        )
      }
    end

    return statements.map {
      |statement|

      self.expand_version_and_explanation(
        statement, statement.minimum_grammar_for_publishing
      )
    }
  end

  def self.expand_version_and_explanation(statement, version_info)
    version, explanation = *version_info
    if explanation.nil?
      return [version]
    end

    return [
      version,
      "Grammar v#{version} is required because the #{statement.statement_type} statement#{statement.position_string} #{explanation}."
    ]
  end


  public

  def unparse(statements)
    # It's double dispatch time!

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

  def grammar_description
    raise NotImplementedError
  end

  private

  def asset(keyword, statement)
    raise NotImplementedError
  end

  def asset_path(statement)
    if @emit_as_input_or_to_be_published_values == :emit_as_input
      return statement.location
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
