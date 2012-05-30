require 'set'
require 'socket'
require 'sys/admin'
require 'tmpdir'

require 'fig'
require 'fig/at_exit'
require 'fig/command'
require 'fig/logging'
require 'fig/not_found_error'
require 'fig/package_cache'
require 'fig/package_descriptor'
require 'fig/parser'
require 'fig/repository_error'
require 'fig/statement/archive'
require 'fig/statement/resource'
require 'fig/url_access_error'

module Fig; end

# Overall management of a repository.  Handles local operations itself;
# defers remote operations to others.
class Fig::Repository
  METADATA_SUBDIRECTORY = '_meta'
  RESOURCES_FILE        = 'resources.tar.gz'
  VERSION_FILE_NAME     = 'repository-format-version'
  VERSION_SUPPORTED     = 1

  def self.is_url?(url)
    not (/ftp:\/\/|http:\/\/|file:\/\/|ssh:\/\// =~ url).nil?
  end

  def initialize(
    os,
    local_repository_directory,
    application_config,
    remote_repository_user,
    check_include_versions
  )
    @operating_system             = os
    @local_repository_directory   = local_repository_directory
    @application_config           = application_config
    @remote_repository_user       = remote_repository_user

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

  def publish_package(package_statements, descriptor, local_only)
    check_local_repository_format()
    if not local_only
      check_remote_repository_format()
    end

    validate_asset_names(package_statements)

    temp_dir = publish_temp_dir()
    @operating_system.delete_and_recreate_directory(temp_dir)
    local_dir = local_dir_for_package(descriptor)
    @operating_system.delete_and_recreate_directory(local_dir)
    fig_file = File.join(temp_dir, PACKAGE_FILE_IN_REPO)
    content = publish_package_content_and_derive_dot_fig_contents(
      package_statements, descriptor, local_dir, local_only
    )
    @operating_system.write(fig_file, content)

    if not local_only
      @operating_system.upload(
        fig_file,
        remote_fig_file_for_package(descriptor),
        @remote_repository_user
      )
    end
    @operating_system.copy(
      fig_file, local_fig_file_for_package(descriptor)
    )

    FileUtils.rm_rf(temp_dir)

    return true
  end

  def update_unconditionally()
    @update_condition = :unconditionally
  end

  def update_if_missing()
    @update_condition = :if_missing
  end

  private

  PACKAGE_FILE_IN_REPO = '.fig'

  def initialize_local_repository()
    if not File.exist?(@local_repository_directory)
      Dir.mkdir(@local_repository_directory)
    end

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

  def validate_asset_names(package_statements)
    asset_statements = package_statements.select { |s| s.is_asset? }

    asset_names = Set.new()
    asset_statements.each do
      |statement|

      asset_name = statement.asset_name()
      if not asset_name.nil?
        if asset_name == RESOURCES_FILE
          Fig::Logging.fatal \
            %Q<You cannot have an asset with the name "#{RESOURCES_FILE}"#{statement.position_string()} due to Fig implementation details.>
        end

        if asset_names.include?(asset_name)
          Fig::Logging.fatal \
            %Q<Found multiple archives with the name "#{asset_name}"#{statement.position_string()}. If these were allowed, archives would overwrite each other.>
          raise Fig::RepositoryError.new
        else
          asset_names.add(asset_name)
        end
      end
    end
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
      Fig::Logging.debug exception
      Fig::Logging.fatal 'Install failed, cleaning up.'

      delete_local_package(descriptor)

      raise Fig::RepositoryError.new
    ensure
      FileUtils.rm_rf(temp_dir)
    end

    return
  end

  def install_package(descriptor, temp_dir)
    @operating_system.delete_and_recreate_directory(temp_dir)

    remote_fig_file = remote_fig_file_for_package(descriptor)
    local_fig_file = fig_file_for_package_download(temp_dir)

    return if not @operating_system.download(remote_fig_file, local_fig_file)

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

    local_dir = local_dir_for_package(descriptor)
    FileUtils.rm_rf(local_dir)
    FileUtils.mkdir_p( File.dirname(local_dir) )
    FileUtils.mv(temp_dir, local_dir)

    return
  end

  # 'resources' is an Array of fileglob patterns: ['tmp/foo/file1',
  # 'tmp/foo/*.jar']
  def expand_globs_from(resources)
    expanded_files = []

    resources.each do
      |path|

      globbed_files = Dir.glob(path)
      if globbed_files.empty?
        expanded_files << path
      else
        expanded_files.concat(globbed_files)
      end
    end

    return expanded_files
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

  def publish_temp_dir()
    File.join(base_temp_dir(), 'publish')
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

  def publish_package_content_and_derive_dot_fig_contents(
    package_statements, descriptor, local_dir, local_only
  )
    header_strings = derive_package_metadata_comments(
      package_statements, descriptor
    )
    deparsed_statement_strings = publish_package_content(
      package_statements, descriptor, local_dir, local_only
    )

    statement_strings = [header_strings, deparsed_statement_strings].flatten()
    return statement_strings.join("\n").gsub(/\n{3,}/, "\n\n").strip() + "\n"
  end

  def derive_package_metadata_comments(package_statements, descriptor)
    now = Time.now()

    asset_statements =
      package_statements.select { |statement| statement.is_asset? }
    asset_strings =
      asset_statements.collect { |statement| statement.unparse('#    ') }
    asset_summary = nil

    if asset_strings.empty?
      asset_summary = [
        %q<#>,
        %q<# There were no asset statements in the unpublished package definition.>
      ]
    else
      asset_summary = [
        %q<#>,
        %q<# Original asset statements: >,
        %q<#>,
        asset_strings
      ]
    end

    return [
      %Q<# Publishing information for #{descriptor.to_string()}:>,
      %q<#>,
      %Q<#     Time: #{now} (epoch: #{now.to_i()})>,
      %Q<#     User: #{Sys::Admin.get_login()}>,
      %Q<#     Host: #{Socket.gethostname()}>,
      %Q<#     Args: "#{ARGV.join %q[", "]}">,
      %Q<#     Fig:  v#{Fig::VERSION}>,
      asset_summary,
      %Q<\n>,
    ].flatten()
  end

  # Deals with Archive and Resource statements.  It downloads any remote
  # files (those where the statement references a URL as opposed to a local
  # file) and then copies all files into the local repository and the remote
  # repository (if not a local-only publish).
  #
  # Returns the deparsed strings for the resource statements with URLs
  # replaced with in-package paths.
  def publish_package_content(
    package_statements, descriptor, local_dir, local_only
  )
    return create_resource_archive(package_statements).map do |statement|
      if statement.is_asset?
        asset_name = statement.asset_name()
        asset_remote = "#{remote_dir_for_package(descriptor)}/#{asset_name}"

        if Fig::Repository.is_url?(statement.url)
          asset_local = File.join(publish_temp_dir(), asset_name)

          begin
            @operating_system.download(statement.url, asset_local)
          rescue Fig::NotFoundError
            Fig::Logging.fatal "Could not download #{statement.url}."
            raise Fig::RepositoryError.new
          end
        else
          asset_local = statement.url
          check_asset_path(asset_local)
        end

        if not local_only
          @operating_system.upload(
            asset_local, asset_remote, @remote_repository_user
          )
        end

        @operating_system.copy(asset_local, local_dir + '/' + asset_name)
        if statement.is_a?(Fig::Statement::Archive)
          @operating_system.unpack_archive(local_dir, asset_name)
        end

        statement.class.new(nil, nil, asset_name).unparse('')
      else
        statement.unparse('')
      end
    end
  end

  # Grabs all of the Resource statements that don't reference URLs, creates a
  # "resources.tar.gz" file containing all the referenced files, strips the
  # Resource statements out of the statements, replacing them with a single
  # Archive statement.  Thus the caller should substitute its set of
  # statements with the return value.
  def create_resource_archive(package_statements)
    asset_paths = []
    new_package_statements = package_statements.reject do |statement|
      if (
        statement.is_a?(Fig::Statement::Resource) &&
        ! Fig::Repository.is_url?(statement.url)
      )
        asset_paths << statement.url
        true
      else
        false
      end
    end

    if asset_paths.size > 0
      asset_paths = expand_globs_from(asset_paths)
      check_asset_paths(asset_paths)

      file = RESOURCES_FILE
      @operating_system.create_archive(file, asset_paths)
      new_package_statements.unshift(
        Fig::Statement::Archive.new(nil, nil, file)
      )
      Fig::AtExit.add { File.delete(file) }
    end

    return new_package_statements
  end

  def check_asset_path(asset_path)
    if not File.exist?(asset_path)
      Fig::Logging.fatal "Could not find file #{asset_path}."
      raise Fig::RepositoryError.new
    end

    return
  end

  def check_asset_paths(asset_paths)
    non_existing_paths =
      asset_paths.select {|path| ! File.exist?(path) && ! File.symlink?(path) }

    if not non_existing_paths.empty?
      if non_existing_paths.size > 1
        Fig::Logging.fatal "Could not find files: #{ non_existing_paths.join(', ') }"
      else
        Fig::Logging.fatal "Could not find file #{non_existing_paths[0]}."
      end

      raise Fig::RepositoryError.new
    end

    return
  end
end
