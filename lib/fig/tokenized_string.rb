module Fig; end

class Fig::TokenizedString
  def initialize(segments, single_quoted)
    @segments      = segments
    @single_quoted = single_quoted

    return
  end

  def single_quoted?()
    return @single_quoted
  end

  def to_expanded_string(&block)
    return (
      @segments.collect { |segment| segment.to_expanded_string(&block) }
    ).join ''
  end

  def to_escaped_string()
    return ( @segments.collect {|segment| segment.to_escaped_string} ).join ''
  end
end
