
module Fig
  class ApplicationConfiguration
    def [](key)
      @data.each do |dataset|
        if dataset.has_key?(key)
          return dataset[key]
        end
      end
      return nil
    end

    def push_dataset(dataset)
      @data.push(dataset)
    end

    def unshift_dataset(dataset)
      @data.unshift(dataset)
    end

    def initialize()
      @data = []
    end
  end
end
