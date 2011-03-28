require 'fileutils'
# Must specify absolute path of ::Archive when using
# this module to avoid conflicts with Fig::Package::Archive
require 'libarchive_ruby' unless RUBY_PLATFORM == 'java'
require 'uri'
require 'net/http'
require 'net/ssh'
require 'net/sftp'
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
      File.open(path, "wb") { |f| f.binmode; f << content }
    end
    
    SUCCESS = 0
    NOT_MODIFIED = 3
    NOT_FOUND = 4
    
    def download_list(url)
      begin
        uri = URI.parse(url)
      rescue 
        puts "Unable to parse url: '#{url}'"
        exit 10
      end
      case uri.scheme
      when "ftp"
        ftp = Net::FTP.new(uri.host)
        ftp.login
        ftp.chdir(uri.path)
        packages = []
        ftp.retrlines('LIST -R .') do |line|
          parts = line.gsub(/\\/, '/').sub(/^\.\//, '').sub(/:$/, '').split('/')
          packages << parts.join('/') if parts.size == 2
        end
        ftp.close
        packages
      when "ssh"
        packages = []
        Net::SSH.start(uri.host, uri.user) do |ssh|
          ls = ssh.exec!("[ -d #{uri.path} ] && find #{uri.path}")
          if not ls.nil?
            ls = ls.gsub(uri.path + "/", "").gsub(uri.path, "")
            ls.each do |line|
              parts = line.gsub(/\\/, '/').sub(/^\.\//, '').sub(/:$/, '').chomp().split('/')
              packages << parts.join('/') if parts.size == 2
            end
          end
        end
        packages
      else
        puts "Protocol not supported: #{url}"
        exit 10
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
        File.open(path, "wb") do |file|
          file.binmode
          http.get(uri.path) do |block|
            file.write(block)
          end
        end
      when "ssh"
        # TODO need better way to do conditional download
        #       timestamp = `ssh #{uri.user + '@' if uri.user}#{uri.host} "ruby -e 'puts File.mtime(\\"#{uri.path}\\").to_i'"`.to_i
        timestamp = File.exist?(path) ? File.mtime(path).to_i : 0 
        cmd = `which fig-download`.strip + " #{timestamp} #{uri.path}"
        ssh_download(uri.user, uri.host, path, cmd)
      else
        puts "Unknown protocol: #{url}"
        exit 10
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
        puts "Unknown archive type: #{basename}"
        exit 10
      end
    end
    
    def upload(local_file, remote_file, user)
      puts "uploading #{local_file} to #{remote_file}"
      uri = URI.parse(remote_file)
      case uri.scheme
      when "ssh"
        ssh_upload(uri.user, uri.host, local_file, remote_file)
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
      Dir.chdir(dir) {
        unless system command
          puts "Command failed"
          exit 10
        end
      }
    end
    
    def copy(source, target)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp_r(source, target)
    end

    def move_file(dir, from, to)
      Dir.chdir(dir) { FileUtils.mv(from, to, :force => true) }
    end
    
    def log_info(msg)
      puts msg
    end

    # Expects files_to_archive as an Array of filenames.
    def create_archive(archive_name, files_to_archive)
      # TODO: Need to verify files_to_archive exists.
      ::Archive.write_open_filename(archive_name, ::Archive::COMPRESSION_GZIP, ::Archive::FORMAT_TAR) do |ar|
        files_to_archive.each do |fn|
          ar.new_entry do |entry|
            entry.copy_stat(fn)
            entry.pathname = fn
            ar.write_header(entry)
            if !entry.directory?
              ar.write_data(open(fn) {|f| f.binmode; f.read })
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

    def self.windows?
      Config::CONFIG['host_os'] =~ /mswin|mingw/
    end

    def self.java?
      RUBY_PLATFORM == 'java'
    end

    def self.unix?
      !windows?
    end

    def shell_exec(cmd)
      if OS.windows?
        Windows.shell_exec_windows(cmd)
      else
        shell_exec_unix(cmd)
      end
    end

    private

    def shell_exec_unix(cmd)
      Kernel.exec(ENV['SHELL'], '-c', cmd.join(' '))
    end

    def shell_exec_windows(cmd)
      #command = ["C:/WINDOWS/system32/cmd.exe", "/C", "call"] + cmd
      command = ["cmd.exe", "/C"] + cmd
      command = command.join(' ')
      Kernel.exec(command)
    end

    # path = The local path the file should be downloaded to.
    # cmd = The command to be run on the remote host.
    def ssh_download(user, host, path, cmd)
      return_code = nil
      tempfile = Tempfile.new("tmp")
      Net::SSH.start(host, user) do |ssh|
        ssh.open_channel do |channel|
          channel.exec(cmd)
          channel.on_data() { |ch, data| tempfile << data }
          channel.on_extended_data() { |ch, type, data| $stderr.puts "SSH Download ERROR: #{data}" }
          channel.on_request("exit-status") { |ch, request|
            return_code = request.read_long
          }
        end
      end

      tempfile.close()

      case return_code
      when NOT_MODIFIED
        tempfile.delete
        return false
      when NOT_FOUND
        tempfile.delete
        puts "File not found: #{path}"
        exit 10
      when SUCCESS
        FileUtils.mv(tempfile.path, path)
        return true
      else
        tempfile.delete
        $stderr.puts "Unable to download file: #{return_code}"
        exit 1
      end
    end

    def ssh_upload(user, host, local_file, remote_file)
      uri = URI.parse(remote_file)
      dir = uri.path[0, uri.path.rindex('/')]
      Net::SSH.start(host, user) do |ssh|
        ssh.exec!("mkdir -p #{dir}")
      end
      Net::SFTP.start(host, user) do |sftp|
        sftp.upload!(local_file, uri.path)
      end
    end

  end
end
