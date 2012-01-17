module Fig; end

class Fig::PackageCache
  def initialize()
    @packages = {}
  end

  def add_package(package)
    versions = @packages[package.package_name]
    if not versions
      versions = {}
      @packages[package.package_name] = versions
    end

    versions[package.version_name] = package

    return
  end

  def get_package(name, version)
    versions = @packages[name]
    return if not versions

    return versions[version]
  end

  def remove_package(name, version)
    versions = @packages[name]
    return if not versions

    versions.delete(version)

    return
  end
end
