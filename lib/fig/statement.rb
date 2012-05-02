module Fig; end

# A statement within a package configuration file (package.fig).
class Fig::Statement
  attr_reader :line, :column, :source_description

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

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(repository, package, configuration, &block)
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
    return '' if not @line
    return '' if not @column

    position_string = " (line #{@line}, column #{@column}"
    if @source_description
      position_string << ", #{@source_description}"
    end
    position_string << ')'

    return position_string
  end
end
