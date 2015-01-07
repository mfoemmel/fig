# coding: utf-8

module Fig; end
class  Fig::TokenizedString; end

class Fig::TokenizedString::PlainSegment
  attr_reader :raw_value

  def initialize(raw_value)
    @raw_value     = raw_value

    return
  end

  def type
    return nil
  end

  def to_expanded_string(&block)
    return @raw_value.gsub(%r< \\ (.) >xm, '\1')
  end

  def to_escaped_string()
    return @raw_value
  end

  # Should not be invoked if original string was single quoted.
  def to_single_quoted_string()
    # Raw value will have come from a non-single quoted string, so we unescape
    # everything (including backslashes) and then escape backslashes and single
    # quotes (which cannot be escaped outside of single quotes).
    return \
      @raw_value.gsub(%r< \\ (.) >xm, '\1').gsub(%r< ([\\']) >xm, '\\\\\1')
  end

  # Should not be invoked if original string was not single quoted.
  def to_double_quotable_string(metacharacters)
    quoted_value = @raw_value.gsub %r< ( ["#{metacharacters}] ) >xm, '\\\\\1'

    quoted_value.gsub!(
      %r<
        (
          (?: ^ | [^\\] ) # New line or non-backslash
          (\\{2})*        # Even number of backslashes
        )

        # All single quotes must have been escaped.  The important bit is to
        # not lose escaped backslashes.
        \\'
      >xm,
      %q<\1'>
    )

    return quoted_value
  end
end
