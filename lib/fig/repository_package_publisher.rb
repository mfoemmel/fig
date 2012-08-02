require 'fileutils'
require 'set'
require 'socket'
require 'sys/admin'
require 'tmpdir'

require 'fig'
require 'fig/at_exit'
require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/package_cache'
require 'fig/package_definition_text_assembler'
require 'fig/package_descriptor'
require 'fig/package_parse_error'
require 'fig/parser'
require 'fig/repository'
require 'fig/repository_error'
require 'fig/statement/archive'
require 'fig/statement/grammar_version'
require 'fig/statement/resource'
require 'fig/url'

module Fig; end

# Handles package publishing for the Repository.
class Fig::RepositoryPackagePublisher
  attr_writer :operating_system
  attr_writer :publish_listeners
  attr_writer :descriptor
  attr_writer :source_package
  attr_writer :was_forced
  attr_writer :base_temp_dir
  attr_writer :local_dir_for_package
  attr_writer :remote_dir_for_package
  attr_writer :local_fig_file_for_package
  attr_writer :remote_fig_file_for_package
  attr_writer :local_only

  def initialize()
    @text_assembler = Fig::PackageDefinitionTextAssembler.new

    return
  end

  def package_statements=(statements)
    @text_assembler.add_input(statements)
  end

  def publish_package()
    derive_publish_metadata()
    validate_asset_names()

    temp_dir = publish_temp_dir()
    @operating_system.delete_and_recreate_directory(temp_dir)
    @operating_system.delete_and_recreate_directory(@local_dir_for_package)

    fig_file = File.join(temp_dir, Fig::Repository::PACKAGE_FILE_IN_REPO)
    content = derive_definition_file
    @operating_system.write(fig_file, content)

    publish_package_contents
    if not @local_only
      @operating_system.upload(fig_file, @remote_fig_file_for_package)
    end
    @operating_system.copy(fig_file, @local_fig_file_for_package)

    notify_listeners

    FileUtils.rm_rf(temp_dir)

    return true
  end

  private

  def derive_publish_metadata()
    @publish_time  = Time.now()
    @publish_login = Sys::Admin.get_login()
    @publish_host  = Socket.gethostname()

    return
  end

  def validate_asset_names()
    asset_statements = @text_assembler.asset_input_statements

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

  def derive_definition_file()
    add_package_metadata_comments()
    add_output_statements_and_create_resource_archive()
    add_unparsed_text()

    file_content = @text_assembler.assemble_package_definition()
    begin
      Fig::Parser.new(nil, false).parse_package(
        @descriptor,
        'the directory should not matter for a consistency check',
        '<package to be published>',
        file_content
      )
    rescue Fig::PackageParseError => error
      raise \
        "Bug in code! Could not parse package definition to be published.\n" +
        "#{error}\n\nGenerated contents:\n#{file_content}"
    end

    return file_content
  end

  def add_package_metadata_comments()
    @text_assembler.add_header(
      %Q<# Publishing information for #{@descriptor.to_string()}:>
    )
    @text_assembler.add_header %q<#>

    @text_assembler.add_header(
      %Q<#     Time: #{@publish_time} (epoch: #{@publish_time.to_i()})>
    )

    @text_assembler.add_header %Q<#     User: #{@publish_login}>
    @text_assembler.add_header %Q<#     Host: #{@publish_host}>
    @text_assembler.add_header %Q<#     Args: "#{ARGV.join %q[", "]}">
    @text_assembler.add_header %Q<#     Fig:  v#{Fig::VERSION}>
    @text_assembler.add_header %Q<\n>

    return
  end

  # Deals with Archive and Resource statements.  It downloads any remote
  # files (those where the statement references a URL as opposed to a local
  # file) and then copies all files into the local repository and the remote
  # repository (if not a local-only publish).
  def add_output_statements_and_create_resource_archive()
    assemble_output_statements()
    create_resource_archive()

    return
  end

  def assemble_output_statements()
    @resource_paths = []

    if (
          @text_assembler.input_statements.empty? \
      ||  ! @text_assembler.input_statements[0].is_a?(Fig::Statement::GrammarVersion)
    )
      @text_assembler.add_output Fig::Statement::GrammarVersion.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        0 # Grammar version
      )
    end

    @text_assembler.input_statements.each do
      |statement|

      if statement.is_asset?
        add_asset_to_output_statements(statement)
      else
        @text_assembler.add_output statement
      end
    end

    return
  end

  def add_asset_to_output_statements(asset_statement)
    if Fig::URL.is_url? asset_statement.location
      @text_assembler.add_output asset_statement
    elsif asset_statement.is_a? Fig::Statement::Archive
      if asset_statement.requires_globbing?
        expand_globs_from( [asset_statement.location] ).each do
          |file|

          @text_assembler.add_output(
            Fig::Statement::Archive.new(
              nil,
              %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
              file,
              false # No globbing
            )
          )
        end
      else
        @text_assembler.add_output asset_statement
      end
    elsif asset_statement.requires_globbing?
      @resource_paths.concat expand_globs_from( [asset_statement.location] )
    else
      @resource_paths << asset_statement.location
    end

    return
  end

  def create_resource_archive()
    if @resource_paths.size > 0
      check_asset_paths(@resource_paths)

      file = Fig::Repository::RESOURCES_FILE
      @operating_system.create_archive(file, @resource_paths)
      Fig::AtExit.add { File.delete(file) }

      @text_assembler.add_output(
        Fig::Statement::Archive.new(
          nil,
          %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
          file,
          false # No globbing
        )
      )
    end

    return
  end

  def publish_package_contents()
    @text_assembler.output_statements.each do
      |statement|

      if statement.is_asset?
        publish_asset(statement)
      end
    end

    return
  end

  def publish_asset(asset_statement)
    asset_name = asset_statement.asset_name()
    asset_remote =
      Fig::URL.append_path_components @remote_dir_for_package, [asset_name]

    if Fig::URL.is_url? asset_statement.location
      asset_local = File.join(publish_temp_dir(), asset_name)

      begin
        @operating_system.download(asset_statement.location, asset_local)
      rescue Fig::FileNotFoundError
        Fig::Logging.fatal "Could not download #{asset_statement.location}."
        raise Fig::RepositoryError.new
      end
    else
      asset_local = asset_statement.location
      check_asset_path(asset_local)
    end

    if not @local_only
      @operating_system.upload(asset_local, asset_remote)
    end

    @operating_system.copy(
      asset_local, @local_dir_for_package + '/' + asset_name
    )
    if asset_statement.is_a?(Fig::Statement::Archive)
      @operating_system.unpack_archive(@local_dir_for_package, asset_name)
    end

    return
  end

  def add_unparsed_text()
    if @source_package && @source_package.unparsed_text
      @text_assembler.add_footer ''
      @text_assembler.add_footer '# Original, unparsed package text:'
      @text_assembler.add_footer '#'
      @text_assembler.add_footer(
        @source_package.unparsed_text.gsub(/^(?=[^\n]+$)/, '# ').gsub(/^$/, '#')
      )
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
    File.join(@base_temp_dir, 'publish')
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

  # 'paths' is an Array of fileglob patterns: ['tmp/foo/file1',
  # 'tmp/foo/*.jar']
  def expand_globs_from(paths)
    expanded_files = []

    paths.each do
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
