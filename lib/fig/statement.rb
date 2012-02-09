module Fig; end

# A statement within a package configuration file (package.fig).
class Fig::Statement
  attr_reader :line, :column

  def initialize(line, column)
    @line   = line
    @column = column
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    return
  end

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(repository, package, configuration, &block)
    return
  end

  def urls
    return []
  end
end
