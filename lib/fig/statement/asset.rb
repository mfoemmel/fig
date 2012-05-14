module Fig; end
class Fig::Statement; end

# Some sort of file to be included in a package.
module Fig::Statement::Asset
  def urls()
    return [ url() ]
  end

  def is_asset?()
    return true
  end

  def standard_asset_name()
    # Not so hot of an idea if the URL has query parameters in it, but not
    # going to fix this now.
    return url().split('/').last()
  end
end
