module Fig; end

# A statement within a package configuration file (package.fig).
module Fig::Statement
  # Block will receive a Statement.
  def walk_statements(&block)
    return
  end

  # Block will receive a Statement.
  def walk_statements_following_package_dependencies(repository, package, &block)
    return
  end

  def urls
    return []
  end
end
