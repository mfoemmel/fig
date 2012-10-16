module Fig; end

class Fig::TokenizedString
  def initialize(segments, single_quoted, metacharacters)
    @segments       = segments
    @single_quoted  = single_quoted
    @metacharacters = metacharacters

    return
  end

  def single_quoted?()
    return @single_quoted
  end

  def can_be_single_quoted?()
    return true if single_quoted?
    return @segments.all? {|segment| segment.type.nil?}
  end

  def to_expanded_string(&block)
    return (
      @segments.collect { |segment| segment.to_expanded_string(&block) }
    ).join ''
  end

  def to_escaped_string()
    return ( @segments.collect {|segment| segment.to_escaped_string} ).join ''
  end

  def to_single_quoted_string()
    return to_escaped_string if single_quoted?

    return (
      @segments.collect {|segment| segment.to_single_quoted_string}
    ).join ''
  end

  def to_double_quoted_string()
    return to_escaped_string if ! single_quoted?

    return (
      @segments.collect {
        |segment| segment.to_double_quoted_string @metacharacters
      }
    ).join ''
  end
end
