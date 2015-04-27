# coding: utf-8

require 'fig/not_yet_parsed_package'
require 'fig/package_descriptor'


module Fig; end


class Fig::NonRepositoryPackages
  def initialize(parser)
    @parser           = parser

    reset_cached_data

    return
  end

  def reset_cached_data
    @packages_by_path = {}

    return
  end

  def [](file_path)
    file_path = File.expand_path file_path
    if package = @packages_by_path[file_path]
      return package
    end

    if ! File.exist? file_path
      return
    end

    load_package file_path

    return @packages_by_path[file_path]
  end


  private

  def load_package(file_path)
    content = File.read file_path

    descriptor =
      Fig::PackageDescriptor.new(nil, nil, nil, :file_path => file_path)

    unparsed_package                    = Fig::NotYetParsedPackage.new
    unparsed_package.descriptor         = descriptor
    unparsed_package.working_directory  =
      unparsed_package.include_file_base_directory =
      File.dirname(file_path)
    unparsed_package.source_description = file_path
    unparsed_package.unparsed_text      = content

    package = @parser.parse_package unparsed_package

    @packages_by_path[file_path] = package

    return
  end
end
