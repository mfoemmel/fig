require 'fileutils'
# Must specify absolute path of ::Archive when using
# this module to avoid conflicts with Fig::Package::Archive
require 'libarchive_ruby' unless RUBY_PLATFORM == 'java'
require 'uri'
require 'net/http'
require 'net/ssh'
require 'net/sftp'
require 'net/netrc'
require 'tempfile'
require 'highline/import'

require 'fig/logging'
require 'fig/networkerror'
require 'fig/notfounderror'

module Fig
  class OS
    def initialize(login)
      @login = login
      @username = ENV['FIG_USERNAME']
      @password = ENV['FIG_PASSWORD']
    end

    def get_username()
      @username ||= ask('Username: ') { |q| q.echo = true }
    end

    def get_password()
      @password ||= ask('Password: ') { |q| q.echo = false }
    end

    def ftp_login(ftp, host)
      if @login
        rc = Net::Netrc.locate(host)
        if rc
          @username = rc.login
          @password = rc.password
        end
        ftp.login(get_username, get_password)
      else
        ftp.login()
      end
      ftp.passive = true
    end

    def list(dir)
      Dir.entries(dir) - ['.','..']
    end

    def mtime(path)
      File.mtime(path)
    end

    def write(path, content)
      File.open(path, 'wb') { |f| f.binmode; f << content }
    end

    SUCCESS = 0
    NOT_MODIFIED = 3
    NOT_FOUND = 4

    def strip_paths_for_list(ls_output, packages, path)
      if not ls_output.nil?
        ls_output = ls_output.gsub(path + '/', '').gsub(path, '').split("\n")
        ls_output.each do |line|
          parts = line.gsub(/\\/, '/').sub(/^\.\//, '').sub(/:$/, '').chomp().split('/')
          packages << parts.join('/') if parts.size == 2
        end
      end
    end

    def download_list(url)
      begin
        uri = URI.parse(url)
      rescue
        Logging.fatal %Q<Unable to parse url: "#{url}">
        raise NetworkError.new(%Q<Unable to parse url: "#{url}">)
      end
      case uri.scheme
      when 'ftp'
        ftp = Net::FTP.new(uri.host)
        ftp_login(ftp, uri.host)
        ftp.chdir(uri.path)
        dirs = ftp.nlst
        ftp.close

        download_ftp_list(uri, dirs)
      when 'ssh'
        packages = []
        Net::SSH.start(uri.host, uri.user) do |ssh|
          ls = ssh.exec!("[ -d #{uri.path} ] && find #{uri.path}")
          strip_paths_for_list(ls, packages, uri.path)
        end
        packages
      when 'file'
        packages = []
        ls = %x<[ -d #{uri.path} ] && find #{uri.path}>
        strip_paths_for_list(ls, packages, uri.path)
        return packages
      else
        Logging.fatal "Protocol not supported: #{url}"
        raise NetworkError.new("Protocol not supported: #{url}")
      end
    end

    def download_ftp_list(uri, dirs)
      # Run a bunch of these in parallel since they're slow as hell
      num_threads = (ENV['FIG_FTP_THREADS'] || '16').to_i
      threads = []
      all_packages = []
      (0..num_threads-1).each { |num| all_packages[num] = [] }
      (0..num_threads-1).each do |num|
        threads << Thread.new do
          packages = all_packages[num]
          ftp = Net::FTP.new(uri.host)
          ftp_login(ftp, uri.host)
          ftp.chdir(uri.path)
          pos = num
          while pos < dirs.length
            pkg = dirs[pos]
            begin
              ftp.nlst(dirs[pos]).each do |ver|
                packages << pkg + '/' + ver
              end
            rescue Net::FTPPermError
              # ignore
            end
            pos += num_threads
          end
          ftp.close
        end
      end
      threads.each { |thread| thread.join }
      all_packages.flatten.sort
    end

    def download(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      uri = URI.parse(url)
      case uri.scheme
      when 'ftp'
        begin
          ftp = Net::FTP.new(uri.host)
          ftp_login(ftp, uri.host)

          if File.exist?(path) && ftp.mtime(uri.path) <= File.mtime(path)
            Logging.debug "#{path} is up to date."
            return false
          else
            log_download(url, path)
            ftp.getbinaryfile(uri.path, path, 256*1024)
            return true
          end
        rescue Net::FTPPermError => error
          Logging.warn error
          raise NotFoundError.new
        rescue SocketError => error
          Logging.warn error
          raise NotFoundError.new
        end
      when 'http'
        http = Net::HTTP.new(uri.host)
        log_download(url, path)
        File.open(path, 'wb') do |file|
          file.binmode
          http.get(uri.path) do |block|
            file.write(block)
          end
        end
      when 'ssh'
        # TODO need better way to do conditional download
        timestamp = File.exist?(path) ? File.mtime(path).to_i : 0
        # Requires that remote installation of fig be at the same location as the local machine.
        cmd = `which fig-download`.strip + " #{timestamp} #{uri.path}"
        log_download(url, path)
        ssh_download(uri.user, uri.host, path, cmd)
      when 'file'
        begin
          FileUtils.cp(uri.path, path)
        rescue Errno::ENOENT => e
          raise NotFoundError.new
        end
      else
        Logging.fatal "Unknown protocol: #{url}"
        raise NetworkError.new("Unknown protocol: #{url}")
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
        Logging.fatal "Unknown archive type: #{basename}"
        raise NetworkError.new("Unknown archive type: #{basename}")
      end
    end

    def upload(local_file, remote_file, user)
      Logging.debug "Uploading #{local_file} to #{remote_file}."
      uri = URI.parse(remote_file)
      case uri.scheme
      when 'ssh'
        ssh_upload(uri.user, uri.host, local_file, remote_file)
      when 'ftp'
        #      fail unless system "curl -T #{local_file} --create-dirs --ftp-create-dirs #{remote_file}"
       require 'net/ftp'
        ftp_uri = URI.parse(ENV['FIG_REMOTE_URL'])
        ftp_root_path = ftp_uri.path
        ftp_root_dirs = ftp_uri.path.split('/')
        remote_publish_path = uri.path[0, uri.path.rindex('/')]
        remote_publish_dirs = remote_publish_path.split('/')
        # Use array subtraction to deduce which project/version folder to upload to,
        # i.e. [1,2,3] - [2,3,4] = [1]
        remote_project_dirs = remote_publish_dirs - ftp_root_dirs
        Net::FTP.open(uri.host) do |ftp|
          ftp_login(ftp, uri.host)
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
      when 'file'
        FileUtils.mkdir_p(File.dirname(uri.path))
        FileUtils.cp(local_file, uri.path)
      else
        Logging.fatal "Unknown protocol: #{uri}"
        raise NetworkError.new("Unknown protocol: #{uri}")
      end
    end

    def clear_directory(dir)
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)
    end

    def copy(source, target, msg = nil)
      if File.directory?(source)
        FileUtils.mkdir_p(target)
        Dir.foreach(source) do |child|
          if child != '.' and child != '..'
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

    def move_file(dir, from, to)
      Dir.chdir(dir) { FileUtils.mv(from, to, :force => true) }
    end

    def log_info(msg)
      Logging.info msg
    end

    # Expects files_to_archive as an Array of filenames.
    def create_archive(archive_name, files_to_archive)
      if OS.java?
        `tar czvf #{archive_name} #{files_to_archive.join(' ')}`
      else
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
    end

    # This method can handle the following archive types:
    # .tar.bz2
    # .tar.gz
    # .tgz
    # .zip
    def unpack_archive(dir, file)
      Dir.chdir(dir) do
        if OS.java?
          `tar xzvf #{file}`
        else
          ::Archive.read_open_filename(file) do |ar|
            while entry = ar.next_header
              ar.extract(entry)
            end
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
      #command = ['C:/WINDOWS/system32/cmd.exe', '/C', 'call'] + cmd
      command = ['cmd.exe', '/C'] + cmd
      command = command.join(' ')
      Kernel.exec(command)
    end

    # path = The local path the file should be downloaded to.
    # cmd = The command to be run on the remote host.
    def ssh_download(user, host, path, cmd)
      return_code = nil
      tempfile = Tempfile.new('tmp')
      Net::SSH.start(host, user) do |ssh|
        ssh.open_channel do |channel|
          channel.exec(cmd)
          channel.on_data() { |ch, data| tempfile << data }
          channel.on_extended_data() { |ch, type, data| Logging.error "SSH Download ERROR: #{data}" }
          channel.on_request('exit-status') { |ch, request|
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
        raise NotFoundError.new
      when SUCCESS
        FileUtils.mv(tempfile.path, path)
        return true
      else
        tempfile.delete
        Logging.fatal "Unable to download file #{path}: #{return_code}"
        raise NetworkError.new("Unable to download file #{path}: #{return_code}")
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

    private

    def log_download(url, path)
      Logging.debug "Downloading #{url} to #{path}."
    end
  end
end
