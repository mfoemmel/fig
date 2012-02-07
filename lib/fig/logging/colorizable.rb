module Fig; end
module Fig::Logging; end

# A String that has colors associated with it.
class Fig::Logging::Colorizable < String
  attr_reader :foreground, :background

  def initialize(string = '', foreground = nil, background = nil)
    super(string)

    @foreground = foreground
    @background = background
  end
end
