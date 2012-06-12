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
require 'fig/repository'
require 'fig/repository_error'
require 'fig/statement/archive'
require 'fig/statement/resource'

module Fig; end

class Fig::RepositoryPackagePublisher
  attr_accessor :operating_system
  attr_accessor :publish_listeners
  attr_accessor :package_statements
  attr_accessor :descriptor
  attr_accessor :source_package
  attr_accessor :base_temp_dir
  attr_accessor :local_dir_for_package
  attr_accessor :remote_dir_for_package
  attr_accessor :local_fig_file_for_package
  attr_accessor :remote_fig_file_for_package
  attr_accessor :local_only

  def publish_package()
    validate_asset_names()

    temp_dir = publish_temp_dir()
    @operating_system.delete_and_recreate_directory(temp_dir)
    local_dir = local_dir_for_package()
    @operating_system.delete_and_recreate_directory(local_dir)
    fig_file = File.join(temp_dir, Fig::Repository::PACKAGE_FILE_IN_REPO)
    content = publish_package_content_and_derive_dot_fig_contents(local_dir)
    @operating_system.write(fig_file, content)

    if not @local_only
      @operating_system.upload(
        fig_file,
        remote_fig_file_for_package()
      )
    end
    @operating_system.copy(fig_file, local_fig_file_for_package())

    @publish_listeners.each do
      |listener|

      listener.published(@descriptor)
    end

    FileUtils.rm_rf(temp_dir)

    return true
  end

  private

  def validate_asset_names()
    asset_statements = @package_statements.select { |s| s.is_asset? }

    asset_names = Set.new()
    asset_statements.each do
      |statement|

      asset_name = statement.asset_name()
      if not asset_name.nil?
        if asset_name == Fig::Repository::RESOURCES_FILE
          Fig::Logging.fatal \
            %Q<You cannot have an asset with the name "#{Fig::Repository::RESOURCES_FILE}"#{statement.position_string()} due to Fig implementation details.>
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

  def publish_temp_dir()
    File.join(base_temp_dir(), 'publish')
  end

  def publish_package_content_and_derive_dot_fig_contents(local_dir)
    header_strings = derive_package_metadata_comments()
    deparsed_statement_strings = publish_package_content(local_dir)

    statement_strings = [header_strings, deparsed_statement_strings]
    if @source_package && @source_package.unparsed_text
      statement_strings << ''
      statement_strings << '# Original, unparsed package text:'
      statement_strings << '# '
      statement_strings << @source_package.unparsed_text.gsub(/^/, '# ')
    end

    statement_strings.flatten!
    return statement_strings.join("\n").gsub(/\n{3,}/, "\n\n").strip() + "\n"
  end

  def derive_package_metadata_comments()
    now = Time.now()

    asset_statements =
      @package_statements.select { |statement| statement.is_asset? }
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
      %Q<# Publishing information for #{@descriptor.to_string()}:>,
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
  def publish_package_content(local_dir)
    return create_resource_archive().map do |statement|
      if statement.is_asset?
        asset_name = statement.asset_name()
        asset_remote = "#{remote_dir_for_package()}/#{asset_name}"

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

        if not @local_only
          @operating_system.upload(
            asset_local, asset_remote
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
  def create_resource_archive()
    asset_paths = []
    new_package_statements = @package_statements.reject do |statement|
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

      file = Fig::Repository::RESOURCES_FILE
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
end
