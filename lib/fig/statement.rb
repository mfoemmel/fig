# coding: utf-8

require 'set'

module Fig; end

# A statement within a package definition file (package.fig).
class Fig::Statement
  ENVIRONMENT_VARIABLE_NAME_REGEX = %r< \A \w+ \z >x

  def self.position_description(line, column, source_description)
    if not line or not column
      return '' if not source_description

      return " (#{source_description})"
    end

    description = " (line #{line}, column #{column}"
    if source_description
      description << ", #{source_description}"
    end
    description << ')'

    return description
  end

  attr_reader :line, :column, :source_description

  # This mess of getting these as a single array necessary is due to
  # limitations of the "*" array splat operator in ruby v1.8.
  def initialize(line_column, source_description)
    if line_column
      @line, @column = *line_column
    end

    @source_description = source_description
  end

  # A name for this kind of Statement, usually a keyword for this statement as
  # it appears in package definition files.
  def statement_type()
    raise NotImplementedError.new(
      "#{__callee__}() not implemented on #{self.class}."
    )
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    return
  end

  def deparse_as_version(deparser)
    raise NotImplementedError.new(
      "#{__callee__}() not implemented on #{self.class}."
    )
  end

  # Returns a two element array containing the version and an explanation of
  # why the version is necessary if the version is greater than 0.
  def minimum_grammar_for_emitting_input()
    raise NotImplementedError.new(
      "#{__callee__}() not implemented on #{self.class}."
    )
  end

  # Returns a two element array containing the version and an explanation of
  # why the version is necessary if the version is greater than 0.
  def minimum_grammar_for_publishing()
    raise NotImplementedError.new(
      "#{__callee__}() not implemented on #{self.class}."
    )
  end

  def urls()
    return []
  end

  def is_asset?()
    return false
  end

  def is_environment_variable?()
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

# vim: set fileencoding=utf8 :
