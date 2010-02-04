require 'fileutils'
# Must specify absolute path of ::Archive when using
# this module to avoid conflicts with Fig::Package::Archive
require 'libarchive_ruby'
require 'uri'
require 'net/http'
require 'tempfile'

module Fig
  class NotFoundException < Exception
  end

  class OS
    def list(dir)
      Dir.entries(dir) - ['.','..']
    end
    
    def exist?(path)
      File.exist?(path)
    end
    
    def mtime(path)
      File.mtime(path)
    end
    
    def read(path)
      File.read(path)
    end
    
    def write(path, content)
      File.open(path, "w") { |f| f << content }
    end
    
    SUCCESS = 0
    NOT_MODIFIED = 3
    NOT_FOUND = 4
    
    def download_list(url)
      uri = URI.parse(url)
      case uri.scheme
      when "ftp"
        ftp = Net::FTP.new(uri.host)
        ftp.login
        dirs = [] 
        ftp.list("-1 " + uri.path) do |line|
          dirs << line
        end
        packages = []
        dirs.each do |dir|
          ftp.list("-1 #{uri.path}/#{dir}") do |line|
            packages << "#{dir}/#{line}"
          end
        end
        packages
      else
        raise "Protocol not supported: #{url}"
      end
    end
    
    def download(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      uri = URI.parse(url)
      case uri.scheme
      when "ftp"
        ftp = Net::FTP.new(uri.host)
        ftp.login
        begin
          if File.exist?(path) && ftp.mtime(uri.path) <= File.mtime(path)
            return false
          else 
            puts "downloading #{url}"
            ftp.getbinaryfile(uri.path, path, 256*1024)
            return true
          end
        rescue Net::FTPPermError
          raise NotFoundException.new
        end
      when "http"
        http = Net::HTTP.new(uri.host)
        puts "downloading #{url}"
        File.open(path, "w") do |file|
          http.get(uri.path) do |block|
            file.write(block)
          end
        end
      when "ssh"
        # TODO need better way to do conditional download
        #       timestamp = `ssh #{uri.user + '@' if uri.user}#{uri.host} "ruby -e 'puts File.mtime(\\"#{uri.path}\\").to_i'"`.to_i
        out = nil
        timestamp = File.exist?(path) ? File.mtime(path).to_i : 0 
        tempfile = Tempfile.new("tmp")
        IO.popen("ssh #{uri.user + '@' if uri.user}#{uri.host} \"fig-download #{timestamp} #{uri.path}\"") do |io|
          first = true 
          while bytes = io.read(4096)
            if first
              $stderr.puts "downloading #{url}"
              first = false
            end
            tempfile << bytes
          end
        end
        tempfile.close
        case $?.exitstatus
        when NOT_MODIFIED
          tempfile.delete
          return false
        when NOT_FOUND
          tempfile.delete
          raise "File not found: #{uri}"
        when SUCCESS
          FileUtils.mv(tempfile.path, path)
          return true
        else
          tempfile.delete
          $stderr.puts "Unable to download file: #{$?.exitstatus}"
          exit 1
        end
      else
        raise "Unknown protocol: #{url}"
      end
   end
    
    def download_resource(url, dir)
      FileUtils.mkdir_p(dir)
      download(url, File.join(dir, URI.parse(url).path.split('/').last))
    end
    
    def download_archive(url, dir)
      FileUtils.mkdir_p(dir)
      basename = URI.parse(url).path.split('/').last
      path = File.join(dir, basename)
      download(url, path)
      case basename
      when /\.tar\.gz$/
        unpack_archive(dir, path)
     when /\.tgz$/
        unpack_archive(dir, path)
      when /\.tar\.bz2$/
        unpack_archive(dir, path)
      when /\.zip$/
        unpack_archive(dir, path)
      else
        raise "Unknown archive type: #{basename}"
      end
    end
    
    def upload(local_file, remote_file, user)
      puts "uploading #{local_file} to #{remote_file}"
      uri = URI.parse(remote_file)
      case uri.scheme
      when "ssh"
        dir = uri.path[0, uri.path.rindex('/')]
       cmd = "mkdir -p #{dir} && cat > #{uri.path}"
        fail unless system "cat #{local_file} | ssh #{uri.user + '@' if uri.user}#{uri.host} '#{cmd}'"
      when "ftp"
        #      fail unless system "curl -T #{local_file} --create-dirs --ftp-create-dirs #{remote_file}"
       require 'net/ftp'
        ftp_uri = URI.parse(ENV["FIG_REMOTE_URL"])
        ftp_root_path = ftp_uri.path
        ftp_root_dirs = ftp_uri.path.split("/")
        remote_publish_path = uri.path[0, uri.path.rindex("/")]
        remote_publish_dirs = remote_publish_path.split("/")
        # Use array subtraction to deduce which project/version folder to upload to,
        # i.e. [1,2,3] - [2,3,4] = [1]
        remote_project_dirs = remote_publish_dirs - ftp_root_dirs
        Net::FTP.open(uri.host) do |ftp|
          ftp.login
          # Assume that the FIG_REMOTE_URL path exists.
          ftp.chdir(ftp_root_path)
          remote_project_dirs.each do |dir|
            # Can't automatically create parent directories, so do it manually.
           if ftp.nlst().index(dir).nil?
             ftp.mkdir(dir)
             ftp.chdir(dir)
           else
             ftp.chdir(dir)
           end
          end
          ftp.putbinaryfile(local_file)
        end
      end
    end
    
    def clear_directory(dir)
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)
    end

    def exec(dir,command)
      Dir.chdir(dir) { raise "Command failed" unless system command }
   end
    
    def copy(source, target)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.copy_file(source, target)
      target
    end
    
    def log_info(msg)
      puts msg
    end

    # Expects files_to_archive as an Array of filenames.
    def create_archive(archive_name, files_to_archive)
      ::Archive.write_open_filename(archive_name, ::Archive::COMPRESSION_GZIP, ::Archive::FORMAT_TAR) do |ar|
        files_to_archive.each do |fn|
          ar.new_entry do |entry|
            entry.copy_stat(fn)
            entry.pathname = fn
            ar.write_header(entry)
            if !entry.directory?
              ar.write_data(open(fn) {|f| f.read })
            end
          end
        end
      end
    end

    # This method can handle the following archive types:
    # .tar.bz2
    # .tar.gz
    # .tgz
    # .zip
    def unpack_archive(dir, file)
      Dir.chdir(dir) do
        ::Archive.read_open_filename(file) do |ar|
          while entry = ar.next_header
            ar.extract(entry)
          end
        end
      end
    end

  end
end
