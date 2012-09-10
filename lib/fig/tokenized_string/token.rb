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

  def to_escaped_string()
    return raw_value
  end
end
