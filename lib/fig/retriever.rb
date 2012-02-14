require 'ostruct'
require 'set'

require 'fig/logging'
require 'fig/logging/colorizable'
require 'fig/packagedescriptor'

module Fig; end

# Copies files from the project directories in FIG_HOME to the user's working
# directory. It keeps track of which files have already been copied, and which
# package/versions they came from, and deletes files as necessary to ensure
# that we never have files from two different versions of the same package in
# the user's working directory.
class Fig::Retriever
  def initialize(base_dir)
    @base_dir = base_dir
    @package_metadata_by_name = {}
    @local_fig_data_directory = File.join(@base_dir, '.fig')

    file = File.join(@local_fig_data_directory, 'retrieve')
    if File.exist?(file)
      load_metadata(file)
    end
  end

  def with_package_version(name, version)
    if name and version
      @package_meta = @package_metadata_by_name[name]
      if @package_meta && @package_meta.version != version
        @package_meta.files.each do |relpath|
          Fig::Logging.info(
            Fig::Logging::Colorizable.new(
              "- [#{formatted_meta()}] #{relpath}",
              :magenta,
              nil
            )
          )
          FileUtils.rm_f(File.join(@base_dir, relpath))
        end
        @package_meta = nil
      end
      if not @package_meta
        @package_meta = new_package_metadata(name, version)
        @package_metadata_by_name[name] = @package_meta
      end
    else
      @package_meta = nil
    end
    yield
  end

  def retrieve(source, relpath)
    copy(source, relpath)
  end

  def save_metadata
    FileUtils.mkdir_p(@local_fig_data_directory)
    File.open(File.join(@local_fig_data_directory, 'retrieve'), 'w') do |f|
      @package_metadata_by_name.each do |name, package_meta|
        package_meta.files.each do |target|
          f << target << '=' << formatted_meta(package_meta) << "\n"
        end
      end
    end
  end

  private

  def load_metadata(file)
    File.open(file).each_line do |line|
      line = line.strip()
      if line =~ /^(.+)=(.+)\/(.+)$/
        target = $1
        package_name = $2
        package_version = $3
        package_meta = @package_metadata_by_name[package_name]
        if package_meta
          if package_meta.version != package_version
            raise 'version mismatch in .figretrieve'
          end
        else
          package_meta = new_package_metadata(package_name, package_version)
          @package_metadata_by_name[package_name] = package_meta
        end
        package_meta.files << target
      else
        raise "parse error in #{file}: #{line}"
      end
    end
  end

  def new_package_metadata(name, version)
    package_meta = OpenStruct.new
    package_meta.name = name
    package_meta.version = version
    package_meta.files = Set.new()

    return package_meta
  end

  def copy(source, relpath)
    target = File.join(@base_dir, relpath)
    if File.directory?(source)
      FileUtils.mkdir_p(target)
      Dir.foreach(source) do |child|
        if child != '.' and child != '..'
          source_file = File.join(source, child)
          target_file = File.join(relpath, child)
          Fig::Logging.debug "Copying #{source_file} to #{target_file}."
          copy(source_file, target_file)
        end
      end
    else
      if ! File.exist?(target) || File.mtime(source) > File.mtime(target)
        if Fig::Logging.debug?
          Fig::Logging.debug \
            "Copying package [#{formatted_meta()}] from #{source} to #{target}."
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

        FileUtils.cp(source, target, :preserve => true)
      end
      @package_meta.files << relpath if @package_meta
    end
  end

  def formatted_meta(package_meta = @package_meta)
    return Fig::PackageDescriptor.format(
      package_meta.name, package_meta.version, nil
    )
  end
end
