module Fig; end

module Fig::Unparser
  attr_reader :indent_string
  attr_reader :initial_indent_level

  def archive(statement)
    raise NotImplementedError
  end

  def command(statement)
    raise NotImplementedError
  end

  def configuration(statement)
    raise NotImplementedError
  end

  def grammar_version(statement)
    raise NotImplementedError
  end

  def include(statement)
    raise NotImplementedError
  end

  def override(statement)
    raise NotImplementedError
  end

  def path(statement)
    raise NotImplementedError
  end

  def resource(statement)
    raise NotImplementedError
  end

  def retrieve(statement)
    raise NotImplementedError
  end

  def set(statement)
    raise NotImplementedError
  end
end
