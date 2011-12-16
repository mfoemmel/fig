module Fig; end
class Fig::Package; end

# A statement within a package configuration file (package.fig).
module Fig::Package::Statement
  def walk_statements(&block)
    return
  end

  def urls
    return []
  end
end
