require 'fig/tokenized_string'
require 'fig/tokenized_string/plain_segment'

module Fig; end

class Fig::StringTokenizer
  def initialize(subexpression_matchers = DEFAULT_SUBEXPRESSION_MATCHER)
    @subexpression_matchers = subexpression_matchers

    return
  end

  # Takes a block that is invoked when there is an error.  Block receives a
  # single parameter of an error message that is the end of a statement
  # describing the problem, with no leading space character.  For example,
  # given «'foo», the block will receive a message like 'has unbalanced single
  # quotes.'.
  #
  # Returns the TokenizedString; if there was a parse error, then the return
  # value will be nil (and the block will have been invoked).
  def tokenize(string, &error_block)
    @string        = string.clone
    @error_block   = error_block
    @single_quoted = nil
    @segments      = []

    strip_quotes_and_process_escapes

    return if @segments.empty?

    return Fig::TokenizedString.new(@segments, @single_quoted)
  end

  private

  DEFAULT_SUBEXPRESSION_MATCHER = [
    { :pattern => %r<\@>, :action => lambda {|character| character} }
  ]

  def strip_quotes_and_process_escapes()
    if @string.length == 0
      @single_quoted = false
      @segments << Fig::TokenizedString::PlainSegment.new('')

      return
    end

    @single_quoted = strip_single_quotes_and_process_escapes
    return if @single_quoted.nil?
    if @single_quoted
      @segments << Fig::TokenizedString::PlainSegment.new(@string.clone)

      return
    end

    strip_double_quotes_and_process_escapes

    return
  end

  def strip_single_quotes_and_process_escapes()
    return false if @string[0..0] != %q<'> && @string[-1..-1] != %q<'>
    return false if @string =~ %r< \A (?: \\{2} )* \\ ' \z >x # «\'» is legal

    if (
      @string.length  == 1                         ||
      @string[0..0]   != %q<'>                     ||
      @string[-1..-1] != %q<'>                     ||
      @string =~ %r< [^\\] (?: \\{2} )* \\ ' \z >x
    )
      @error_block.call 'has unbalanced single quotes.'
      return
    end

    if @string =~ %r< [^\\] (?: \\{2} )*? \\ ([^\\']) >x
      @error_block.call(
        "contains a bad escape sequence (\\#{$1}) inside single quotes."
      )
      return
    end

    @string.sub!( %r< \A ' (.*) ' \z >xm, '\1')

    return true
  end

  def strip_double_quotes_and_process_escapes()
    return if ! check_and_strip_double_quotes

    if @string == %q<\\'>
      @segments << Fig::TokenizedString::PlainSegment.new(%q<'>)

      return
    end

    generate_segments

    return
  end

  def check_and_strip_double_quotes()
    # We accept any unquoted single character at this point.  Later validation
    # will catch bad characters.
    return true if @string =~ %r< \A \\ . \z >xm

    if @string[0..0] == %q<">
      if @string.length == 1 || @string[-1..-1] != %q<">
        @error_block.call 'has unbalanced double quotes.'
        return
      end
      if @string =~ %r< [^\\] (?: \\{2} )*? \\ " \z >xm
        @error_block.call \
          'has unbalanced double quotes; the trailing double quote is escaped.'
        return
      end

      @string.sub!( %r< \A " (.*) " \z >xm, '\1' )
    elsif @string =~ %r< (?: \A | [^\\] ) (?: \\{2} )* " \z >xm
      @error_block.call \
        %q<has unbalanced double quotes; it ends in a double quote when it didn't start with one.>
      return
    end

    return true
  end

  def generate_segments()
    plain_string = nil

    while ! @string.empty?
      if @string =~ %r< \A (\\+) ([^\\] .*)? \z >xm
        slashes, remainder = $1, $2
        if slashes.length % 2 == 1
          if remainder.nil?
            @error_block.call 'ends in an incomplete escape.'
            return
          end
          if subexpression_match(remainder) || remainder[0..0] == %q<">
            plain_string ||= ''
            plain_string << slashes
            plain_string << remainder[0..0]
            @string = remainder[1..-1] || ''
          else
            @error_block.call "contains a bad escape sequence (\\#{$1})."
            return
          end
        else
          plain_string ||= ''
          plain_string << slashes
          @string = remainder
        end
      else
        replacement, remainder = subexpression_match @string
        if replacement
          if replacement.is_a? String
            plain_string << replacement
          else
            @segments << Fig::TokenizedString::PlainSegment.new(plain_string)
            plain_string = nil
          end
          @string = remainder
        elsif @string =~ %r< \A (["']) >xm # Fix single quotes in quoted strings
          quote_name = $1 == %q<'> ? 'single' : 'double'
          @error_block.call "contains an unescaped #{quote_name} quote."
          return
        else
          plain_string ||= ''
          plain_string << @string[0..0]
          @string = @string[1..-1] || ''
        end
      end
    end

    if plain_string
      @segments << Fig::TokenizedString::PlainSegment.new(plain_string)
    end

    return
  end

  def subexpression_match(sub_string)
    @subexpression_matchers.each do
      |matcher|

      pattern = matcher[:pattern]
      if sub_string =~ %r< \A ( #{pattern} ) >x
        subexpression, remainder = $1, $'
        replacement = matcher[:action].call subexpression
        return [replacement, remainder]
      end
    end

    return
  end
end
