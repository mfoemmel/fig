require 'ostruct'

# This class copies files from the project directories in ~/.fighome to the 
# user's working directory. It keeps track of which files have already been copied, and which 
# package/versions they came from, and deletes files as necessary to ensure that
# we never have files from two different versions of the same package in the user's 
# working directory. 
class Retriever
  def initialize(base_dir)
    @base_dir = base_dir
    @configs = {}
    @fig_dir = File.join(@base_dir, ".fig")

    file = File.join(@fig_dir, "retrieve")
    if File.exist?(file)
      load(file)
    end
  end

  def with_config(name, version)
    if name and version
      @config = @configs[name]
      if @config && @config.version != version
        @config.files.each do |relpath|
          FileUtils.rm_f(File.join(@base_dir, relpath))
        end
      end
      @config = new_config(name, version)
      @configs[name] = @config
    else
      @config = nil
    end
    yield
  end

  def retrieve(source, relpath)
    copy(source, File.join(@base_dir, relpath))
    @config.files << relpath if @config
  end

  def save
    FileUtils.mkdir_p(@fig_dir)
    File.open(File.join(@fig_dir, "retrieve"), 'w') do |f|
      @configs.each do |name,config|
        config.files.each do |target|
          f << target << "=" << config.name << "/" << config.version << "\n"
        end
      end
    end
  end

private

  def load(file)
    File.open(file).each_line do |line|
      line = line.strip()
      if line =~ /^(.+)=(.+)\/(.+)$/
        target = $1
        config_name = $2
        config_version = $3
        config = @configs[config_name]
        if config
          if config.version != config_version
            raise "version mismatch in .figretrieve"
          end
        else
          config = new_config(config_name, config_version)
          @configs[config_name] = config
        end
        config.files << target
      else
        raise "parse error in #{file}: #{line}"
      end
    end
  end

  def new_config(name, version) 
    config = OpenStruct.new
    config.name = name
    config.version = version
    config.files = []
    return config
  end

  def copy(source, target)
    if File.directory?(source)
      FileUtils.mkdir_p(target)
      Dir.foreach(source) do |child|
        if child != "." and child != ".."
          copy(File.join(source, child), File.join(target, child))
        end
      end
    else
      if !File.exist?(target) || File.mtime(source) != File.mtime(target)
        $stderr.puts "retriving #{target}"
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)
        File.utime(File.atime(source), File.mtime(source), target)
      end
    end
  end
end
