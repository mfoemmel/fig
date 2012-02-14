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

    def self.is_url?(url)
      not (/ftp:\/\/|http:\/\/|file:\/\/|ssh:\/\// =~ url).nil?
    end

    def initialize(
      os,
      local_repository_dir,
      remote_repository_url,
      application_config,
      remote_repository_user  = nil,
      update                  = false,
      update_if_missing       = true
    )
      @operating_system = os
      @local_repository_dir = local_repository_dir
      @remote_repository_url = remote_repository_url
      @remote_repository_user = remote_repository_user
      @update = update
      @update_if_missing = update_if_missing

      @parser = Parser.new(application_config)

      reset_cached_data()
    end

    def reset_cached_data()
      @packages = PackageCache.new()
    end

    def list_packages
      results = []
      if File.exist?(@local_repository_dir)
        @operating_system.list(@local_repository_dir).each do |name|
          @operating_system.list(File.join(@local_repository_dir, name)).each do |version|
            results << PackageDescriptor.format(name, version, nil)
          end
        end
      end

      return results
    end

    def list_remote_packages
      paths = @operating_system.download_list(@remote_repository_url)

      return paths.reject { |path| path =~ %r< ^ #{METADATA_SUBDIRECTORY} / >xs }
    end

    def get_package(
      descriptor,
      disable_updating = false,
      allow_any_version = false
    )
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

      if should_update?(descriptor, disable_updating)
        update_package(descriptor)
      end

      return read_local_package(descriptor)
    end

    def clean(descriptor)
      @packages.remove_package(descriptor.name, descriptor.version)

      dir = File.join(@local_repository_dir, descriptor.name)
      dir = File.join(dir, descriptor.version) if descriptor.version

      FileUtils.rm_rf(dir)

      return
    end

    def publish_package(package_statements, descriptor, local_only)
      temp_dir = temp_dir_for_package(descriptor)
      @operating_system.clear_directory(temp_dir)
      local_dir = local_dir_for_package(descriptor)
      @operating_system.clear_directory(local_dir)
      fig_file = File.join(temp_dir, '.fig')
      content = derive_package_content(
        package_statements, descriptor, local_dir, local_only
      )
      @operating_system.write(fig_file, content.join("\n").strip)
      @operating_system.upload(
        fig_file,
        remote_fig_file_for_package(descriptor),
        @remote_repository_user
      ) unless local_only
      @operating_system.copy(
        fig_file, local_fig_file_for_package(descriptor)
      )

      FileUtils.rm_rf(temp_dir)
    end

    def updating?
      return @update || @update_if_missing
    end

    private

    def should_update?(descriptor, disable_updating)
      return false if disable_updating

      return true if @update

      return @update_if_missing && package_missing?(descriptor)
    end

    def read_local_package(descriptor)
      directory = local_dir_for_package(descriptor)
      return read_package_from_directory(directory, descriptor)
    end

    def bundle_resources(package_statements)
      resources = []
      new_package_statements = package_statements.reject do |statement|
        if (
          statement.is_a?(Statement::Resource) &&
          ! Repository.is_url?(statement.url)
        )
          resources << statement.url
          true
        else
          false
        end
      end

      if resources.size > 0
        resources = expand_globs_from(resources)
        file = 'resources.tar.gz'
        @operating_system.create_archive(file, resources)
        new_package_statements.unshift(Statement::Archive.new(nil, file))
        at_exit { File.delete(file) }
      end

      return new_package_statements
    end

    def install_package(descriptor)
      temp_dir = nil

      begin
        package = read_local_package(descriptor)
        temp_dir = temp_dir_for_package(descriptor)
        @operating_system.clear_directory(temp_dir)
        package.archive_urls.each do |archive_url|
          if not Repository.is_url?(archive_url)
            archive_url = remote_dir_for_package(descriptor) + '/' + archive_url
          end
          @operating_system.download_archive(archive_url, File.join(temp_dir))
        end
        package.resource_urls.each do |resource_url|
          if not Repository.is_url?(resource_url)
            resource_url =
              remote_dir_for_package(descriptor) + '/' + resource_url
          end
          @operating_system.download_resource(resource_url, File.join(temp_dir))
        end
        local_dir = local_dir_for_package(descriptor)
        @operating_system.clear_directory(local_dir)
        # some packages contain no files, only a fig file.
        if not (package.archive_urls.empty? && package.resource_urls.empty?)
          FileUtils.mv(Dir.glob(File.join(temp_dir, '*')), local_dir)
        end
        write_local_package(descriptor, package)
      rescue
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
        Logging.fatal "Package not found in remote repository: #{descriptor.to_string()}"
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
      "#{@remote_repository_url}/#{descriptor.name}/#{descriptor.version}/.fig"
    end

    def local_fig_file_for_package(descriptor)
      File.join(local_dir_for_package(descriptor), '.fig')
    end

    def remote_dir_for_package(descriptor)
      "#{@remote_repository_url}/#{descriptor.name}/#{descriptor.version}"
    end

    def local_dir_for_package(descriptor)
      return File.join(
        @local_repository_dir, descriptor.name, descriptor.version
      )
    end

    def temp_dir_for_package(descriptor)
      File.join(@local_repository_dir, 'tmp')
    end

    def package_missing?(descriptor)
      not File.exist?(local_fig_file_for_package(descriptor))
    end

    def derive_package_content(
      package_statements, descriptor, local_dir, local_only
    )
      header_strings = derive_package_metadata_comments(descriptor)
      resource_statement_strings = derive_package_resources(
        package_statements, descriptor, local_dir, local_only
      )

      return [header_strings, resource_statement_strings].flatten()
    end

    def derive_package_metadata_comments(descriptor)
      now = Time.now()

      return [
        "# Publishing information for #{descriptor.to_string()}:",
        '#',
        "#    Time: #{now} (epoch: #{now.to_i()})",
        "#    User: #{derive_user_name()}",
        "#    Host: #{Socket.gethostname()}",
        '#'
      ]
    end

    def derive_user_name()
      login = Sys::Admin.get_login()
      user = Sys::Admin.get_user(login)

      user_name = nil
      if user.respond_to?('full_name') # Windows
        user_name = user.full_name()
      elsif user.respond_to?('gecos')  # *nix
        user_name = user.gecos()
      end

      if user_name
        return "#{user_name} (#{login})"
      end

      return login
    end

    def derive_package_resources(
      package_statements, descriptor, local_dir, local_only
    )
      return bundle_resources(package_statements).map do |statement|
        if statement.is_a?(Statement::Publish)
          nil
        elsif statement.is_a?(Statement::Archive) || statement.is_a?(Statement::Resource)
          if statement.is_a?(Statement::Resource) && ! Repository.is_url?(statement.url)
            archive_name = statement.url
            archive_remote = "#{remote_dir_for_package(descriptor)}/#{statement.url}"
          else
            archive_name = statement.url.split('/').last
            archive_remote = "#{remote_dir_for_package(descriptor)}/#{archive_name}"
          end
          if Repository.is_url?(statement.url)
            archive_local = File.join(temp_dir, archive_name)
            @operating_system.download(statement.url, archive_local)
          else
            archive_local = statement.url
          end
          @operating_system.upload(archive_local, archive_remote, @remote_repository_user) unless local_only
          @operating_system.copy(archive_local, local_dir + '/' + archive_name)
          if statement.is_a?(Statement::Archive)
            @operating_system.unpack_archive(local_dir, archive_name)
          end
          statement.class.new(nil, archive_name).unparse('')
        else
          statement.unparse('')
        end
      end.select { |s|not s.nil? }
    end
  end
end
