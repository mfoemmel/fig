module Fig; end

# Configuration for the Fig program, as opposed to the configuration in a
# package.
class Fig::ApplicationConfiguration
  def initialize(remote_repository_url)
    @data = []
    @remote_repository_url = remote_repository_url
    clear_cached_data
  end

  def ensure_url_whitelist_initialized()
    return if not @whitelist.nil?
    whitelist = self['url whitelist']
    if whitelist.nil?
      @whitelist = []
    else
      @whitelist = [@remote_repository_url, whitelist].flatten
    end
  end

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

  # after push_dataset or unshift_dataset, call clear_cached, and lazy
  # initialize as far as the list of things to exclude
  def clear_cached_data()
    @whitelist = nil
  end

  def url_access_allowed?(url)
    ensure_url_whitelist_initialized
    return true if @whitelist.empty?
    @whitelist.each do |allowed_url|
      return true if url.match(/\A#{Regexp.quote(allowed_url)}\b/)
    end
    return false
  end
end
