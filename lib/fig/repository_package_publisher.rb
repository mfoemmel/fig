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
  attr_accessor :was_forced
  attr_accessor :base_temp_dir
  attr_accessor :local_dir_for_package
  attr_accessor :remote_dir_for_package
  attr_accessor :local_fig_file_for_package
  attr_accessor :remote_fig_file_for_package
  attr_accessor :local_only

  def publish_package()
    derive_publish_metadata()
    validate_asset_names()

    temp_dir = publish_temp_dir()
    @operating_system.delete_and_recreate_directory(temp_dir)
    @operating_system.delete_and_recreate_directory(@local_dir_for_package)

    fig_file = File.join(temp_dir, Fig::Repository::PACKAGE_FILE_IN_REPO)
    content = publish_package_content_and_derive_definition_file()
    @operating_system.write(fig_file, content)

    if not @local_only
      @operating_system.upload(fig_file, remote_fig_file_for_package())
    end
    @operating_system.copy(fig_file, local_fig_file_for_package())

    notify_listeners

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

  def derive_publish_metadata()
    @publish_time  = Time.now()
    @publish_login = Sys::Admin.get_login()
    @publish_host  = Socket.gethostname()

    return
  end

  def publish_package_content_and_derive_definition_file()
    @definition_file_lines = []

    add_package_metadata_comments()
    publish_package_content()
    add_unparsed_text()

    @definition_file_lines.flatten!
    file_content = @definition_file_lines.join("\n")
    file_content.gsub!(/\n{3,}/, "\n\n")

    return file_content.strip() + "\n"
  end

  def add_package_metadata_comments()
    @definition_file_lines <<
      %Q<# Publishing information for #{@descriptor.to_string()}:>
    @definition_file_lines << %q<#>

    @definition_file_lines <<
      %Q<#     Time: #{@publish_time} (epoch: #{@publish_time.to_i()})>

    @definition_file_lines << %Q<#     User: #{@publish_login}>
    @definition_file_lines << %Q<#     Host: #{@publish_host}>
    @definition_file_lines << %Q<#     Args: "#{ARGV.join %q[", "]}">
    @definition_file_lines << %Q<#     Fig:  v#{Fig::VERSION}>
    @definition_file_lines << %q<#>

    asset_statements =
      @package_statements.select { |statement| statement.is_asset? }
    asset_strings =
      asset_statements.collect { |statement| statement.unparse('#    ') }

    if asset_strings.empty?
      @definition_file_lines <<
        %q<# There were no asset statements in the unpublished package definition.>
    else
      @definition_file_lines << %q<# Original asset statements: >
      @definition_file_lines << %q<#>
      @definition_file_lines << asset_strings
    end

    @definition_file_lines << %Q<\n>

    return
  end

  # Deals with Archive and Resource statements.  It downloads any remote
  # files (those where the statement references a URL as opposed to a local
  # file) and then copies all files into the local repository and the remote
  # repository (if not a local-only publish).
  def publish_package_content()
    initialize_statements_to_publish()
    create_resource_archive()

    @statements_to_publish.each do
      |statement|

      if statement.is_asset?
        publish_asset(statement)
      else
        @definition_file_lines << statement.unparse('')
      end
    end

    return
  end

  def initialize_statements_to_publish()
    @resource_paths = []

    @statements_to_publish = @package_statements.reject do |statement|
      if (
        statement.is_a?(Fig::Statement::Resource) &&
        ! Fig::Repository.is_url?(statement.url)
      )
        @resource_paths << statement.url
        true
      else
        false
      end
    end

    return
  end

  def create_resource_archive()
    if @resource_paths.size > 0
      asset_paths = expand_globs_from(@resource_paths)
      check_asset_paths(asset_paths)

      file = Fig::Repository::RESOURCES_FILE
      @operating_system.create_archive(file, asset_paths)
      Fig::AtExit.add { File.delete(file) }

      @statements_to_publish.unshift(
        Fig::Statement::Archive.new(nil, nil, file)
      )
    end

    return
  end

  def publish_asset(asset_statement)
    asset_name = asset_statement.asset_name()
    asset_remote = "#{remote_dir_for_package()}/#{asset_name}"

    if Fig::Repository.is_url?(asset_statement.url)
      asset_local = File.join(publish_temp_dir(), asset_name)

      begin
        @operating_system.download(asset_statement.url, asset_local)
      rescue Fig::NotFoundError
        Fig::Logging.fatal "Could not download #{asset_statement.url}."
        raise Fig::RepositoryError.new
      end
    else
      asset_local = asset_statement.url
      check_asset_path(asset_local)
    end

    if not @local_only
      @operating_system.upload(
        asset_local, asset_remote
      )
    end

    @operating_system.copy(
      asset_local, @local_dir_for_package + '/' + asset_name
    )
    if asset_statement.is_a?(Fig::Statement::Archive)
      @operating_system.unpack_archive(@local_dir_for_package, asset_name)
    end

    @definition_file_lines <<
      asset_statement.class.new(nil, nil, asset_name).unparse('')

    return
  end

  def add_unparsed_text()
    if @source_package && @source_package.unparsed_text
      @definition_file_lines << ''
      @definition_file_lines << '# Original, unparsed package text:'
      @definition_file_lines << '# '
      @definition_file_lines << @source_package.unparsed_text.gsub(/^/, '# ')
    end

    return
  end

  def notify_listeners()
    publish_information = {}
    publish_information[:descriptor]          = @descriptor
    publish_information[:time]                = @publish_time
    publish_information[:login]               = @publish_login
    publish_information[:host]                = @publish_host

    # Ensure that we've really got booleans and not merely true or false
    # values.
    publish_information[:was_forced]          = @was_forced ? true : false
    publish_information[:local_only]          = @local_only ? true : false

    publish_information[:local_destination]   = @local_dir_for_package
    publish_information[:remote_destination]  = @remote_dir_for_package

    @publish_listeners.each do
      |listener|

      listener.published(publish_information)
    end

    return
  end

  def publish_temp_dir()
    File.join(base_temp_dir(), 'publish')
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
