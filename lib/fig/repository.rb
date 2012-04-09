require 'set'
require 'socket'
require 'sys/admin'

require 'fig/logging'
require 'fig/notfounderror'
require 'fig/packagecache'
require 'fig/packagedescriptor'
require 'fig/parser'
require 'fig/repositoryerror'
require 'fig/statement/archive'
require 'fig/statement/resource'
require 'fig/urlaccesserror'

module Fig
  # Overall management of a repository.  Handles local operations itself;
  # defers remote operations to others.
  class Repository
    METADATA_SUBDIRECTORY = '_meta'
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
      update,
      update_if_missing,
      check_include_versions
    )
      @operating_system             = os
      @local_repository_directory   = local_repository_directory
      @application_config           = application_config
      @remote_repository_user       = remote_repository_user
      @update                       = update
      @update_if_missing            = update_if_missing

      @parser = Parser.new(application_config, check_include_versions)

      initialize_local_repository()
      reset_cached_data()
    end

    def reset_cached_data()
      @packages = PackageCache.new()
    end

    def list_packages
      check_local_repository_format()

      results = []
      if File.exist?(local_package_directory())
        @operating_system.list(local_package_directory()).each do |name|
          @operating_system.list(File.join(local_package_directory(), name)).each do
            |version|
            results << PackageDescriptor.format(name, version, nil)
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
          package = @packages.get_any_version_of_package(descriptor.name)
          if package
            Logging.warn(
              "Picked version #{package.version} of #{package.name} at random."
            )
            return package
          end
        end

        raise RepositoryError.new(
          %Q<Cannot retrieve "#{descriptor.name}" without a version.>
        )
      end

      package = @packages.get_package(descriptor.name, descriptor.version)
      return package if package

      Logging.debug \
        "Considering #{PackageDescriptor.format(descriptor.name, descriptor.version, nil)}."

      if should_update?(descriptor)
        check_remote_repository_format()

        update_package(descriptor)
      end

      return read_local_package(descriptor)
    end

    def clean(descriptor)
      check_local_repository_format()

      @packages.remove_package(descriptor.name, descriptor.version)

      FileUtils.rm_rf(local_dir_for_package(descriptor))

      return
    end

    def publish_package(package_statements, descriptor, local_only)
      check_local_repository_format()
      if not local_only
        check_remote_repository_format()
      end

      check_for_unique_asset_names(package_statements)

      temp_dir = temp_dir()
      @operating_system.delete_and_recreate_directory(temp_dir)
      local_dir = local_dir_for_package(descriptor)
      @operating_system.delete_and_recreate_directory(local_dir)
      fig_file = File.join(temp_dir, '.fig')
      content = publish_package_content_and_derive_dot_fig_contents(
        package_statements, descriptor, local_dir, local_only
      )
      @operating_system.write(fig_file, content.join("\n").strip)

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

    def updating?
      return @update || @update_if_missing
    end

    private

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
        Logging.fatal \
          "#{name} repository is in version #{version} format. This version of fig can only deal with repositories in version #{VERSION_SUPPORTED} format."
        raise RepositoryError.new
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
        temp_dir = temp_dir()
        @operating_system.delete_and_recreate_directory(temp_dir)
        remote_version_file = "#{remote_repository_url()}/#{VERSION_FILE_NAME}"
        local_version_file = File.join(temp_dir, "remote-#{VERSION_FILE_NAME}")
        begin
          @operating_system.download(remote_version_file, local_version_file)
        rescue NotFoundError
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
        Logging.fatal \
          %Q<Could not parse the contents of "#{description}" ("#{version_string}") as a version.>
        raise RepositoryError.new
      end

      return version_string.to_i()
    end

    def check_for_unique_asset_names(package_statements)
      asset_statements = package_statements.select { |s| s.is_asset? }

      asset_names = Set.new()
      asset_statements.each do
        |statement|

        asset_name = statement.asset_name()
        if not asset_name.nil?
          if asset_names.include?(asset_name)
            Logging.fatal \
              %Q<Found multiple archives with the name "#{asset_name}". If these were allowed, archives would overwrite each other.>
            raise RepositoryError.new
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
      return true if @update

      return @update_if_missing && package_missing?(descriptor)
    end

    def read_local_package(descriptor)
      directory = local_dir_for_package(descriptor)
      return read_package_from_directory(directory, descriptor)
    end

    def install_package(descriptor)
      temp_dir = nil

      begin
        package = read_local_package(descriptor)
        temp_dir = temp_dir()
        @operating_system.delete_and_recreate_directory(temp_dir)
        package.archive_urls.each do |archive_url|
          if not Repository.is_url?(archive_url)
            archive_url = remote_dir_for_package(descriptor) + '/' + archive_url
          end
          @operating_system.download_and_unpack_archive(archive_url, temp_dir)
        end
        package.resource_urls.each do |resource_url|
          if not Repository.is_url?(resource_url)
            resource_url =
              remote_dir_for_package(descriptor) + '/' + resource_url
          end
          @operating_system.download_resource(resource_url, temp_dir)
        end
        local_dir = local_dir_for_package(descriptor)
        @operating_system.delete_and_recreate_directory(local_dir)
        # some packages contain no files, only a fig file.
        if not (package.archive_urls.empty? && package.resource_urls.empty?)
          FileUtils.mv(Dir.glob(File.join(temp_dir, '*')), local_dir)
        end
        write_local_package(descriptor, package)
      rescue StandardError => exception
        Logging.debug exception
        Logging.fatal 'Install failed, cleaning up.'
        delete_local_package(descriptor)
        raise RepositoryError.new
      ensure
        if temp_dir
          FileUtils.rm_rf(temp_dir)
        end
      end
    end

    def update_package(descriptor)
      remote_fig_file = remote_fig_file_for_package(descriptor)
      local_fig_file = local_fig_file_for_package(descriptor)
      begin
        if @operating_system.download(remote_fig_file, local_fig_file)
          install_package(descriptor)
        end
      rescue NotFoundError
        Logging.fatal \
          "Package not found in remote repository: #{descriptor.to_string()}"
        delete_local_package(descriptor)
        raise RepositoryError.new
      end
    end

    # 'resources' is an Array of fileglob patterns: ['tmp/foo/file1',
    # 'tmp/foo/*.jar']
    def expand_globs_from(resources)
      expanded_files = []
      resources.each {|f| expanded_files.concat(Dir.glob(f))}
      expanded_files
    end

    def read_package_from_directory(dir, descriptor)
      file = nil
      dot_fig_file = File.join(dir, '.fig')
      if File.exist?(dot_fig_file)
        file = dot_fig_file
      else
        package_dot_fig_file = File.join(dir, 'package.fig')
        if not File.exist?(package_dot_fig_file)
          Logging.fatal %Q<Fig file not found for package "#{descriptor.name || '<unnamed>'}". Looked for "#{dot_fig_file}" and "#{package_dot_fig_file}" and found neither.>
          raise RepositoryError.new
        end

        file = package_dot_fig_file
      end

      return read_package_from_file(file, descriptor)
    end

    def read_package_from_file(file_name, descriptor)
      if not File.exist?(file_name)
        Logging.fatal "Package not found: #{descriptor.to_string()}"
        raise RepositoryError.new
      end
      content = File.read(file_name)

      package = @parser.parse_package(
        descriptor, File.dirname(file_name), content
      )

      @packages.add_package(package)

      return package
    end

    def delete_local_package(descriptor)
      FileUtils.rm_rf(local_dir_for_package(descriptor))
    end

    def write_local_package(descriptor, package)
      file = local_fig_file_for_package(descriptor)
      @operating_system.write(file, package.unparse)
    end

    def remote_fig_file_for_package(descriptor)
      "#{remote_dir_for_package(descriptor)}/.fig"
    end

    def local_fig_file_for_package(descriptor)
      File.join(local_dir_for_package(descriptor), '.fig')
    end

    def remote_dir_for_package(descriptor)
      "#{remote_repository_url()}/#{descriptor.name}/#{descriptor.version}"
    end

    def local_dir_for_package(descriptor)
      return File.join(
        local_package_directory(), descriptor.name, descriptor.version
      )
    end

    def temp_dir()
      File.join(@local_repository_directory, 'tmp')
    end

    def package_missing?(descriptor)
      not File.exist?(local_fig_file_for_package(descriptor))
    end

    def publish_package_content_and_derive_dot_fig_contents(
      package_statements, descriptor, local_dir, local_only
    )
      header_strings = derive_package_metadata_comments(descriptor)
      deparsed_statement_strings = publish_package_content(
        package_statements, descriptor, local_dir, local_only
      )

      return [header_strings, deparsed_statement_strings].flatten()
    end

    def derive_package_metadata_comments(descriptor)
      now = Time.now()

      return [
        %Q<# Publishing information for #{descriptor.to_string()}:>,
        %q<#>,
        %Q<#    Time: #{now} (epoch: #{now.to_i()})>,
        %Q<#    User: #{Sys::Admin.get_login()}>,
        %Q<#    Host: #{Socket.gethostname()}>,
        %Q<#    Args: "#{ARGV.join %q[", "]}">,
        %q<#>
      ]
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
        if statement.is_a?(Statement::Publish)
          nil
        elsif statement.is_asset?
          asset_name = statement.asset_name()
          asset_remote = "#{remote_dir_for_package(descriptor)}/#{asset_name}"

          if Repository.is_url?(statement.url)
            asset_local = File.join(temp_dir(), asset_name)
            @operating_system.download(statement.url, asset_local)
          else
            asset_local = statement.url
          end

          if not local_only
            @operating_system.upload(
              asset_local, asset_remote, @remote_repository_user
            )
          end

          @operating_system.copy(asset_local, local_dir + '/' + asset_name)
          if statement.is_a?(Statement::Archive)
            @operating_system.unpack_archive(local_dir, asset_name)
          end
          statement.class.new(nil, asset_name).unparse('')
        else
          statement.unparse('')
        end
      end.select { |s| not s.nil? }
    end

    # Grabs all of the Resource statements that don't reference URLs, creates a
    # "resources.tar.gz" file containing all the referenced files, strips the
    # Resource statements out of the statements, replacing them with a single
    # Archive statement.  Thus the caller should substitute its set of
    # statements with the return value.
    def create_resource_archive(package_statements)
      resource_paths = []
      new_package_statements = package_statements.reject do |statement|
        if (
          statement.is_a?(Statement::Resource) &&
          ! Repository.is_url?(statement.url)
        )
          resource_paths << statement.url
          true
        else
          false
        end
      end

      if resource_paths.size > 0
        resource_paths = expand_globs_from(resource_paths)
        file = 'resources.tar.gz'
        @operating_system.create_archive(file, resource_paths)
        new_package_statements.unshift(Statement::Archive.new(nil, file))
        at_exit { File.delete(file) }
      end

      return new_package_statements
    end
  end
end
