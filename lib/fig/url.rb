module Fig; end

module Fig::URL
  def self.is_url?(url)
    not (/ftp:\/\/|https?:\/\/|file:\/\/|ssh:\/\// =~ url).nil?
  end
end
