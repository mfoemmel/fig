# coding: utf-8

module Fig; end
class  Fig::TokenizedString; end

class Fig::TokenizedString::Token
  attr_reader :type
  attr_reader :raw_value

  def initialize(type, raw_value)
    @type      = type
    @raw_value = raw_value

    return
  end

  def to_expanded_string(&block)
    return block.call self
  end

  def to_escaped_string()
    return raw_value
  end

  def to_double_quotable_string(metacharacters)
    return raw_value
  end

  def to_single_quoted_string()
    raise NotImplementedError.new 'Cannot single-quote a token.'
  end
end
