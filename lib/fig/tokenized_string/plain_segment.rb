module Fig; end
class  Fig::TokenizedString; end

class Fig::TokenizedString::PlainSegment
  attr_reader :raw_value

  def initialize(raw_value)
    @raw_value     = raw_value

    return
  end

  def type
    return :plain_segment
  end

  def to_expanded_string()
    return @raw_value.gsub(%r< \\ (.) >xm, '\1')
  end

  def to_escaped_string()
    return @raw_value
  end
end
