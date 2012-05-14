module Fig; end

# A statement within a package definition file (package.fig).
class Fig::Statement
  attr_reader :line, :column, :source_description

  def self.position_description(line, column, source_description)
    return '' if not line
    return '' if not column

    description = " (line #{line}, column #{column}"
    if source_description
      description << ", #{source_description}"
    end
    description << ')'

    return description
  end

  # This mess of getting these as a single array necessary is due to
  # limitations of the "*" array splat operator in ruby v1.8.
  def initialize(line_column, source_description)
    if line_column
      @line, @column = *line_column
    end

    @source_description = source_description
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    return
  end

  def urls()
    return []
  end

  def is_asset?()
    return false
  end

  # Returns a representation of the position of this statement, if the position
  # is known, empty string otherwise.  This is written with the idea that you
  # can do something like "puts %Q<Found a
  # statement%{statement.position_string()}.>" and get nice looking output
  # regardless of whether the position is actually known or not.
  def position_string
    return Fig::Statement.position_description(
      @line, @column, @source_description
    )
  end
end
