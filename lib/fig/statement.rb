module Fig; end

# A statement within a package configuration file (package.fig).
class Fig::Statement
  attr_reader :line, :column

  # This mess of getting these as a single array necessary is due to
  # limitations of the "*" array splat operator in ruby v1.8.
  def initialize(line_column)
    if line_column
      @line, @column = *line_column
    end
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

  # Returns a representation of the position of this statement, if the position
  # is known, empty string otherwise.  This is written with the idea that you
  # can do something like "puts %Q<Found a
  # statement%{statement.position_string()}.>" and get nice looking output
  # regardless of whether the position is actually known or not.
  def position_string
    return '' if not @line
    return '' if not @column

    return " (line #{@line}, column #{@column})"
  end
end
