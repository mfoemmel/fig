require 'set'

require 'fig/logging'
require 'fig/logging/colorizable'
require 'fig/package_descriptor'
require 'fig/working_directory_metadata'

module Fig; end

# Copies files from the project directories in FIG_HOME to the user's working
# directory. It keeps track of which files have already been copied, and which
# package/versions they came from, and deletes files as necessary to ensure
# that we never have files from two different versions of the same package in
# the user's working directory.
class Fig::WorkingDirectoryMaintainer
  def initialize(base_dir)
    @base_dir = base_dir
    @package_metadata_by_name = {}
    @local_fig_data_directory = File.join(@base_dir, '.fig')
    @metadata_file = File.join(@local_fig_data_directory, 'retrieve')

    if File.exist?(@metadata_file)
      load_metadata()
    end
  end

  def switch_to_package_version(name, version)
    @package_meta = @package_metadata_by_name[name]
    if @package_meta && @package_meta.current_version != version
      clean_up_package_files()
      @package_meta = nil
    end
    if not @package_meta
      @package_meta = reset_package_metadata_with_version(name, version)
    end

    return
  end

  def retrieve(source, relpath)
    copy(source, relpath)

    return
  end

  def prepare_for_shutdown(purged_unused_packages)
    if purged_unused_packages
      clean_up_unused_packages()
    end

    save_metadata()

    return
  end

  private

  def load_metadata()
    File.open(@metadata_file).each_line do |line|
      line.strip!()
      if line =~ /^(.+)=(.+)\/(.+)$/
        target          = $1
        package_name    = $2
        package_version = $3

        package_meta = @package_metadata_by_name[package_name]
        if package_meta
          if package_meta.current_version != package_version
            raise "Version mismatch for #{package_meta.package_name} in #{@metadata_file}."
          end
        else
          package_meta =
            reset_package_metadata_with_version(package_name, package_version)
        end
        package_meta.add_file(target)
      else
        raise "parse error in #{@metadata_file}: #{line}"
      end
    end

    return
  end

  def reset_package_metadata_with_version(name, version)
    metadata = @package_metadata_by_name[name]
    if not metadata
      metadata = Fig::WorkingDirectoryMetadata.new(name, version)
      @package_metadata_by_name[name] = metadata
    else
      metadata.reset_with_version(version)
    end

    return metadata
  end

  def copy(source, relpath)
    target = File.join(@base_dir, relpath)

    if source_and_target_are_same?(source, target)
      # Actually happened: Retrieve and "set" both set to ".". Victim's current
      # directory included a ".git" directory. Update was done and then later,
      # an update with different dependencies. Fig proceeded to delete all
      # files that had previously existed in the current directory, including
      # out of the git repo. Whoops.
      Fig::Logging.warn %Q<Skipping copying "#{source}" to itself.>
      return
    end

    if File.directory?(source)
      copy_directory(source, relpath, target)
    else
      copy_file(source, relpath, target)
    end

    return
  end

  def source_and_target_are_same?(source, target)
    source_absolute = File.absolute_path(source)
    target_absolute = File.absolute_path(target)

    return source_absolute == target_absolute
  end

  def copy_directory(source, relpath, target)
    FileUtils.mkdir_p(target)
    Fig::Logging.debug "Copying directory #{source} to #{target}."

    Dir.foreach(source) do |child|
      if child != '.' and child != '..'
        source_file = File.join(source, child)
        target_file = File.join(relpath, child)
        copy(source_file, target_file)
      end
    end

    return
  end

  def copy_file(source, relpath, target)
    if should_copy_file?(source, target)
      if Fig::Logging.debug?
        Fig::Logging.debug \
          "Copying file from #{source} to #{target}."
      else
        Fig::Logging.info(
          Fig::Logging::Colorizable.new(
            "+ [#{formatted_meta()}] #{relpath}",
            :green,
            nil
          )
        )
      end
      FileUtils.mkdir_p(File.dirname(target))

      # If the source is a dangling symlink, then there's no time, etc. to
      # preserve.
      preserve = File.exist?(source) && ! File.symlink?(source)

      FileUtils.copy_entry(
        source, target, preserve, false, :remove_destination
      )
    end

    if @package_meta
      @package_meta.add_file(relpath)
      @package_meta.mark_as_retrieved()
    end

    return
  end

  def should_copy_file?(source, target)
    if File.symlink?(target)
      FileUtils.rm(target)
      return true
    end

    return true if ! File.exist?(target)
    return File.mtime(source) > File.mtime(target)
  end

  def clean_up_package_files(package_meta = @package_meta)
    package_meta.each_file do |relpath|
      Fig::Logging.info(
        Fig::Logging::Colorizable.new(
          "- [#{formatted_meta(package_meta)}] #{relpath}",
          :magenta,
          nil
        )
      )
      FileUtils.rm_f(File.join(@base_dir, relpath))
    end

    return
  end

  def clean_up_unused_packages()
    @package_metadata_by_name.each_value do
      |metadata|

      if not metadata.retrieved?
        clean_up_package_files(metadata)
        metadata.reset_with_version(nil)
      end
    end

    return
  end

  def save_metadata()
    FileUtils.mkdir_p(@local_fig_data_directory)
    File.open(@metadata_file, 'w') do |file|
      @package_metadata_by_name.each do |name, package_meta|
        package_meta.each_file do |target|
          file << target << '=' << formatted_meta(package_meta) << "\n"
        end
      end
    end

    return
  end

  def formatted_meta(package_meta = @package_meta)
    return Fig::PackageDescriptor.format(
      package_meta.package_name, package_meta.current_version, nil
    )
  end
end
