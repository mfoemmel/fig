
module Fig
  class ApplicationConfiguration
    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
      return nil
    end

    def initialize(data)
      @data = data
    end
  end
end
