require 'ostruct'

class Retriever
  def initialize(base_dir)
    @base_dir = base_dir
    @configs = {}

    file = File.join(@base_dir, ".figretrieve")
    if File.exist?(file)
      load(file)
    end
  end

  def with_config(name, version)
    @config = @configs[name]
    if @config && @config.version != version
      @config.files.each do |relpath|
        FileUtils.rm_f(File.join(@base_dir, relpath))
      end
    end
    @config = new_config(name, version)
    @configs[name] = @config
    yield
  end

  def retrieve(source, relpath)
    copy(source, File.join(@base_dir, relpath))
    @config.files << relpath
  end

  def save
    File.open(File.join(@base_dir, ".figretrieve"), 'w') do |f|
      @configs.each do |name,config|
        @config.files.each do |target|
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
        raise "parse error in .figretrieve: #{line}"
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

  def copy(source, target, msg = nil)
    if File.directory?(source)
      FileUtils.mkdir_p(target)
      Dir.foreach(source) do |child|
        if child != "." and child != ".."
          copy(File.join(source, child), File.join(target, child), msg)
        end
      end
    else
      if !File.exist?(target) || File.mtime(source) != File.mtime(target)
        log_info "#{msg} #{target}" if msg
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)
        File.utime(File.atime(source), File.mtime(source), target)
      end
    end
  end
end
