# coding: utf-8

module Fig; end

# Configuration for the Fig program, as opposed to a config in a package.
class Fig::ApplicationConfiguration
  attr_accessor :base_whitelisted_url
  attr_accessor :remote_repository_url

  def initialize()
    @data = []
    clear_cached_data
  end

  def ensure_url_whitelist_initialized()
    return if not @whitelist.nil?
    whitelist = self['url whitelist']
    if whitelist.nil?
      @whitelist = []
    elsif @base_whitelisted_url
      @whitelist = [@base_whitelisted_url, whitelist].flatten
    elsif whitelist.is_a? Array
      @whitelist = whitelist
    else
      @whitelist = [whitelist]
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

  # After push_dataset, call clear_cached, and lazy initialize as far as the
  # list of things to exclude
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
