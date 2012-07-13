# coding: utf-8

require 'set'

module Fig; end

# A statement within a package definition file (package.fig).
class Fig::Statement
  ENVIRONMENT_VARIABLE_NAME_REGEX = %r< \A \w+ \z >x

  attr_reader :line, :column, :source_description

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

  # Parameter will be modified.
  #
  # Takes a block that is invoked when there is an error.  Block receives a
  # single parameter of an error message that is the end of a statement
  # describing the problem, with no leading space character.  For example,
  # given «'foo», the block will receive a message like 'has unbalanced single
  # quotes.'.
  #
  # Returns whether parameter was single-quoted; if there was a parse error,
  # then the return value will be nil (and the block will have been invoked).
  def self.strip_quotes_and_process_escapes!(string, &error_block)
    return false if string.length == 0

    replaced_quotes = strip_single_quotes!(string, &error_block)
    return true if replaced_quotes
    return      if replaced_quotes.nil?

    return process_escapes_and_strip_double_quotes!(string, &error_block)
  end

  private

  def self.strip_single_quotes!(string)
    return false if string[0..0] != %q<'> && string[-1..-1] != %q<'>

    if string.length == 1 || string[0..0] != %q<'> || string[-1..-1] != %q<'>
      yield 'has unbalanced single quotes.'
      return
    end

    if string =~ %r< \A ' [^']* ' .* ' \z >xs
      yield %q<isn't permitted because it has a single quote inside single quotes.>
      return
    end

    string.sub!(%r< \A ' (.*) ' \z >xs, '\1')

    return true
  end

  ALLOWED_ESCAPED_CHARACTERS = Set.new
  ALLOWED_ESCAPED_CHARACTERS << '\\'
  ALLOWED_ESCAPED_CHARACTERS << %q<'>
  ALLOWED_ESCAPED_CHARACTERS << %q<">
  ALLOWED_ESCAPED_CHARACTERS << '@' # Environment variable package replacement

  def self.process_escapes_and_strip_double_quotes!(string)
    if string[0..0] == %q<"> && (string.length == 1 || string[-1..-1] != %q<">)
      yield 'has unbalanced double quotes.'
      return
    end

    new_string = ''

    characters = string.each_char
    initial_character   = characters.next
    last_character      = nil
    had_starting_quote  = initial_character == %q<">
    in_escape           = initial_character == '\\'
    if ! had_starting_quote && ! in_escape
      new_string << initial_character
    end

    last_was_escaped = nil
    loop do
      last_character = character = characters.next
      if in_escape
        if ! ALLOWED_ESCAPED_CHARACTERS.include? character
          yield "contains a bad escape sequence (\\#{character})."
          return
        end

        new_string << character
        in_escape = false
        last_was_escaped = true
      elsif character == %q<">
        # If we're at the end of the string, we'll get bounced out of the loop
        # by a StopIteration exception.
        characters.next
        yield 'has an unescaped double quote in the middle.'
        return
      elsif character == %q<'>
        yield 'has an unescaped single quote in the middle.'
        return
      elsif character == '\\'
        in_escape = true
      # TODO: need an
      #   «elsif character == '@'»
      # here to deal with package substitution in variable statements
      else
        new_string << character
        last_was_escaped = false
      end
    end

    if in_escape
      yield 'ends in an incomplete escape sequence.'
      return
    elsif had_starting_quote
      if last_was_escaped
        yield 'has unbalanced double quotes (last quote was escaped).'
        return
      end
    elsif ! last_was_escaped && ! had_starting_quote && last_character == %q<">
      yield 'has unbalanced double quotes.'
      return
    end

    string.replace(new_string)

    return false
  end

  public

  # This mess of getting these as a single array necessary is due to
  # limitations of the "*" array splat operator in ruby v1.8.
  def initialize(line_column, source_description)
    if line_column
      @line, @column = *line_column
    end

    @source_description = source_description
  end

  # Block will receive a Statement and the current statement containment level.
  def walk_statements(current_containment_level = 0, &block)
    return
  end

  def unparse_as_version(unparser)
    raise NotImplementedError
  end

  def minimum_grammar_version_required()
    raise NotImplementedError
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
