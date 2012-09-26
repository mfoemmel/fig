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
    return \
      @raw_value.gsub(%r< \\ (.) >xm, '\1').gsub(%r< ([\\']) >xm, '\\\\\1')
  end
end
