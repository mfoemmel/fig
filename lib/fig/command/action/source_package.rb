# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::SourcePackage
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--get>
  end

  def descriptor_requirement()
    return nil
  end

  def modifies_repository?()
    return false
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return true
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return true
  end

  def configure(options)
    @file = options.file_to_find_package_for
  end

  def execute()
    if ! File.exist? @file
      $stderr.puts %Q<"#{@file}" does not exist.>
      return EXIT_FAILURE
    end
    if File.directory? @file
      $stderr.puts %Q<"#{@file}" is a directory. Fig does not keep track of directories.>
      return EXIT_FAILURE
    end

    maintainer = @execution_context.working_directory_maintainer
    package_version = maintainer.find_package_version_for_file @file
    if ! package_version
      $stderr.puts %Q<Don't know anything about "#{@file}".>
      return EXIT_FAILURE
    end

    puts package_version

    return EXIT_SUCCESS
  end
end
