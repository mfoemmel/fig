require 'fileutils'
require 'set'
require 'socket'
require 'sys/admin'
require 'tmpdir'

require 'fig'
require 'fig/at_exit'
require 'fig/logging'
require 'fig/not_found_error'
require 'fig/package_cache'
require 'fig/package_descriptor'
require 'fig/parser'
require 'fig/repository_error'
require 'fig/repository_package_publisher'

module Fig; end

# Overall management of a repository.  Handles local operations itself;
# defers remote operations to others.
class Fig::Repository
  METADATA_SUBDIRECTORY = '_meta'
  PACKAGE_FILE_IN_REPO  = '.fig'
  RESOURCES_FILE        = 'resources.tar.gz'
  VERSION_FILE_NAME     = 'repository-format-version'
  VERSION_SUPPORTED     = 1

  def self.is_url?(url)
    not (/ftp:\/\/|https?:\/\/|file:\/\/|ssh:\/\// =~ url).nil?
  end

  def initialize(
    os,
    local_repository_directory,
    application_config,
    publish_listeners,
    check_include_versions
  )
    @operating_system             = os
    @local_repository_directory   = local_repository_directory
    @application_config           = application_config
    @publish_listeners            = publish_listeners

    @parser = Fig::Parser.new(application_config, check_include_versions)

    initialize_local_repository()
    reset_cached_data()
  end

  def reset_cached_data()
    @package_cache = Fig::PackageCache.new()
  end

  def list_packages
    check_local_repository_format()

    results = []
    if File.exist?(local_package_directory())
      @operating_system.list(local_package_directory()).each do |name|
        @operating_system.list(File.join(local_package_directory(), name)).each do
          |version|
          results << Fig::PackageDescriptor.format(name, version, nil)
        end
      end
    end

    return results
  end

  def list_remote_packages
    check_remote_repository_format()

    paths = @operating_system.download_list(remote_repository_url())

    return paths.reject { |path| path =~ %r< ^ #{METADATA_SUBDIRECTORY} / >xs }
  end

  def get_package(
    descriptor,
    allow_any_version = false
  )
    check_local_repository_format()

    if not descriptor.version
      if allow_any_version
        package = @package_cache.get_any_version_of_package(descriptor.name)
        if package
          Fig::Logging.warn(
            "Picked version #{package.version} of #{package.name} at random."
          )
          return package
        end
      end

      raise Fig::RepositoryError.new(
        %Q<Cannot retrieve "#{descriptor.name}" without a version.>
      )
    end

    package = @package_cache.get_package(descriptor.name, descriptor.version)
    return package if package

    Fig::Logging.debug \
      "Considering #{Fig::PackageDescriptor.format(descriptor.name, descriptor.version, nil)}."

    if should_update?(descriptor)
      check_remote_repository_format()

      update_package(descriptor)
    end

    return read_local_package(descriptor)
  end

  def clean(descriptor)
    check_local_repository_format()

    @package_cache.remove_package(descriptor.name, descriptor.version)

    FileUtils.rm_rf(local_dir_for_package(descriptor))

    return
  end

  def publish_package(
    package_statements, descriptor, local_only, source_package, was_forced
  )
    check_local_repository_format()
    if not local_only
      check_remote_repository_format()
    end

    publisher = Fig::RepositoryPackagePublisher.new
    publisher.operating_system       = @operating_system
    publisher.publish_listeners      = @publish_listeners
    publisher.package_statements     = package_statements
    publisher.descriptor             = descriptor
    publisher.source_package         = source_package
    publisher.was_forced             = was_forced
    publisher.base_temp_dir          = base_temp_dir
    publisher.local_dir_for_package  = local_dir_for_package(descriptor)
    publisher.remote_dir_for_package = remote_dir_for_package(descriptor)
    publisher.local_only             = local_only
    publisher.local_fig_file_for_package =
      local_fig_file_for_package(descriptor)
    publisher.remote_fig_file_for_package =
      remote_fig_file_for_package(descriptor)

    return publisher.publish_package()
  end

  def update_unconditionally()
    @update_condition = :unconditionally
  end

  def update_if_missing()
    @update_condition = :if_missing
  end

  private

  def initialize_local_repository()
    FileUtils.mkdir_p(@local_repository_directory)

    version_file = local_version_file()
    if not File.exist?(version_file)
      File.open(version_file, 'w') { |handle| handle.write(VERSION_SUPPORTED) }
    end

    return
  end

  def check_local_repository_format()
    check_repository_format('Local', local_repository_version())

    return
  end

  def check_remote_repository_format()
    check_repository_format('Remote', remote_repository_version())

    return
  end

  def check_repository_format(name, version)
    if version != VERSION_SUPPORTED
      Fig::Logging.fatal \
        "#{name} repository is in version #{version} format. This version of fig can only deal with repositories in version #{VERSION_SUPPORTED} format."
      raise Fig::RepositoryError.new
    end

    return
  end

  def local_repository_version()
    if @local_repository_version.nil?
      version_file = local_version_file()

      @local_repository_version =
        parse_repository_version(version_file, version_file)
    end

    return @local_repository_version
  end

  def local_version_file()
    return File.join(@local_repository_directory, VERSION_FILE_NAME)
  end

  def local_package_directory()
    return File.expand_path(File.join(@local_repository_directory, 'repos'))
  end

  def remote_repository_version()
    if @remote_repository_version.nil?
      temp_dir = base_temp_dir()
      @operating_system.delete_and_recreate_directory(temp_dir)
      remote_version_file = "#{remote_repository_url()}/#{VERSION_FILE_NAME}"
      local_version_file = File.join(temp_dir, "remote-#{VERSION_FILE_NAME}")
      begin
        @operating_system.download(remote_version_file, local_version_file)
      rescue Fig::NotFoundError
        # The download may create an empty file, so get rid of it.
        if File.exist?(local_version_file)
          File.unlink(local_version_file)
        end
      end

      @remote_repository_version =
        parse_repository_version(local_version_file, remote_version_file)
    end

    return @remote_repository_version
  end

  def parse_repository_version(version_file, description)
    if not File.exist?(version_file)
      return 1 # Since there was no version file early in Fig development.
    end

    version_string = IO.read(version_file)
    version_string.strip!()
    if version_string !~ / \A \d+ \z /x
      Fig::Logging.fatal \
        %Q<Could not parse the contents of "#{description}" ("#{version_string}") as a version.>
      raise Fig::RepositoryError.new
    end

    return version_string.to_i()
  end

  def remote_repository_url()
    return @application_config.remote_repository_url()
  end

  def should_update?(descriptor)
    return true if @update_condition == :unconditionally

    return @update_condition == :if_missing && package_missing?(descriptor)
  end

  def read_local_package(descriptor)
    directory = local_dir_for_package(descriptor)
    return read_package_from_directory(directory, descriptor)
  end

  def update_package(descriptor)
    temp_dir = package_download_temp_dir(descriptor)
    begin
      install_package(descriptor, temp_dir)
    rescue Fig::NotFoundError
      Fig::Logging.fatal \
        "Package not found in remote repository: #{descriptor.to_string()}"

      delete_local_package(descriptor)

      raise Fig::RepositoryError.new
    rescue StandardError => exception
      Fig::Logging.fatal %Q<Install failed, cleaning up: #{exception}>

      delete_local_package(descriptor)

      raise Fig::RepositoryError.new
    ensure
      FileUtils.rm_rf(temp_dir)
    end

    return
  end

  def install_package(descriptor, temp_dir)
    remote_fig_file = remote_fig_file_for_package(descriptor)
    local_dir       = local_dir_for_package(descriptor)
    local_fig_file  = fig_file_for_package_download(local_dir)
    return if not @operating_system.download(remote_fig_file, local_fig_file)

    @operating_system.delete_and_recreate_directory(temp_dir)

    temp_fig_file = fig_file_for_package_download(temp_dir)

    @operating_system.download(remote_fig_file, temp_fig_file)

    package = read_package_from_directory(temp_dir, descriptor)

    package.archive_urls.each do |archive_url|
      if not Fig::Repository.is_url?(archive_url)
        archive_url = remote_dir_for_package(descriptor) + '/' + archive_url
      end
      @operating_system.download_and_unpack_archive(archive_url, temp_dir)
    end
    package.resource_urls.each do |resource_url|
      if not Fig::Repository.is_url?(resource_url)
        resource_url =
          remote_dir_for_package(descriptor) + '/' + resource_url
      end
      @operating_system.download_resource(resource_url, temp_dir)
    end

    FileUtils.rm_rf(local_dir)
    FileUtils.mkdir_p( File.dirname(local_dir) )
    FileUtils.mv(temp_dir, local_dir)

    return
  end

  def read_package_from_directory(directory, descriptor)
    dot_fig_file = File.join(directory, PACKAGE_FILE_IN_REPO)
    if not File.exist?(dot_fig_file)
      Fig::Logging.fatal %Q<Fig file not found for package "#{descriptor.name || '<unnamed>'}". There is nothing in "#{dot_fig_file}".>
      raise Fig::RepositoryError.new
    end

    return read_package_from_file(dot_fig_file, descriptor)
  end

  def read_package_from_file(file_name, descriptor)
    if not File.exist?(file_name)
      Fig::Logging.fatal "Package not found: #{descriptor.to_string()}"
      raise Fig::RepositoryError.new
    end
    content = File.read(file_name)

    package = @parser.parse_package(
      descriptor, File.dirname(file_name), descriptor.to_string(), content
    )

    @package_cache.add_package(package)

    return package
  end

  def delete_local_package(descriptor)
    FileUtils.rm_rf(local_dir_for_package(descriptor))
  end

  def remote_fig_file_for_package(descriptor)
    "#{remote_dir_for_package(descriptor)}/#{PACKAGE_FILE_IN_REPO}"
  end

  def local_fig_file_for_package(descriptor)
    File.join(local_dir_for_package(descriptor), PACKAGE_FILE_IN_REPO)
  end

  def fig_file_for_package_download(package_download_dir)
    File.join(package_download_dir, PACKAGE_FILE_IN_REPO)
  end

  def remote_dir_for_package(descriptor)
    "#{remote_repository_url()}/#{descriptor.name}/#{descriptor.version}"
  end

  def local_dir_for_package(descriptor)
    return File.join(
      local_package_directory(), descriptor.name, descriptor.version
    )
  end

  def base_temp_dir()
    File.join(@local_repository_directory, 'tmp')
  end

  def package_download_temp_dir(descriptor)
    base_directory = File.join(base_temp_dir(), 'package-download')
    FileUtils.mkdir_p(base_directory)

    return Dir.mktmpdir(
      "#{descriptor.name}.version.#{descriptor.version}+", base_directory
    )
  end

  def package_missing?(descriptor)
    not File.exist?(local_fig_file_for_package(descriptor))
  end
end
