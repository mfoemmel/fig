# coding: utf-8

require 'set'

module Fig; end

# Data about a package within the current working directory.
class Fig::WorkingDirectoryMetadata
  attr_reader   :package_name, :current_version

  def initialize(package_name, current_version = nil)
    @package_name    = package_name
    @retrieved       = false

    reset_with_version(current_version)
  end

  def reset_with_version(new_version)
    @current_version = new_version
    @files           = Set.new

    return
  end

  def add_file(file)
    @files << file

    return
  end

  def mark_as_retrieved()
    @retrieved = true

    return
  end

  def retrieved?()
    return @retrieved
  end

  # So we don't have to expose the files collection.
  def each_file()
    @files.each {|file| yield file}

    return
  end
end
