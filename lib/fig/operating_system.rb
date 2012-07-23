require 'fileutils'
require 'find'
# Must specify absolute path of ::Archive when using
# this module to avoid conflicts with Fig::Statement::Archive
require 'libarchive_ruby' unless RUBY_PLATFORM == 'java'
require 'net/http'
require 'net/ssh'
require 'net/sftp'
require 'net/netrc'
require 'rbconfig'
require 'tempfile'
require 'uri'

require 'highline/import'

require 'fig/at_exit'
require 'fig/environment_variables/case_insensitive'
require 'fig/environment_variables/case_sensitive'
require 'fig/logging'
require 'fig/network_error'
require 'fig/not_found_error'

module Fig; end

# Does things requiring real O/S interaction, primarilly taking care of file
# transfers and running external commands.
class Fig::OperatingSystem
  def initialize(login)
    @login = login
    @username = ENV['FIG_USERNAME']
    @password = ENV['FIG_PASSWORD']
  end

  def get_username()
    # #ask() comes from highline
    @username ||= ask('Username: ') { |q| q.echo = true }
  end

  def get_password()
    # #ask() comes from highline
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
      Fig::Logging.fatal %Q<Unable to parse url: "#{url}">
      raise Fig::NetworkError.new
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
      return packages if ! File.exist?(uri.path)

      ls = ''
      Find.find(uri.path) { |file| ls << file.to_s; ls << "\n" }

      strip_paths_for_list(ls, packages, uri.path)
      return packages
    else
      Fig::Logging.fatal "Protocol not supported: #{url}"
      raise Fig::NetworkError.new("Protocol not supported: #{url}")
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
            # Ignore this error because it's indicative of the FTP library
            # encountering a file or directory that it does not have
            # permission to open.  Fig needs to be able to have secure
            # repos/packages and there is no way easy way to deal with the
            # permissions issues other than consuming these errors.
            #
            # Actually, with FTP, you can't tell the difference between a
            # file not existing and not having permission to access it (which
            # is probably a good thing).
          end
          pos += num_threads
        end
        ftp.close
      end
    end
    threads.each { |thread| thread.join }
    all_packages.flatten.sort
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(url, path)
    FileUtils.mkdir_p(File.dirname(path))
    uri = URI.parse(url)
    case uri.scheme
    when 'ftp'
      begin
        ftp = Net::FTP.new(uri.host)
        ftp_login(ftp, uri.host)

        if File.exist?(path) && ftp.mtime(uri.path) <= File.mtime(path)
          Fig::Logging.debug "#{path} is up to date."
          return false
        else
          log_download(url, path)
          ftp.getbinaryfile(uri.path, path, 256*1024)
          return true
        end
      rescue Net::FTPPermError => error
        Fig::Logging.debug error.message
        raise Fig::NotFoundError.new error.message, url
      rescue SocketError => error
        Fig::Logging.debug error.message
        raise Fig::NotFoundError.new error.message, url
      end
    when 'http'
      log_download(url, path)
      File.open(path, 'wb') do |file|
        file.binmode

        begin
          download_via_http_get(url, file)
        rescue SystemCallError => error
          Fig::Logging.debug error.message
          raise Fig::NotFoundError.new error.message, url
        rescue SocketError => error
          Fig::Logging.debug error.message
          raise Fig::NotFoundError.new error.message, url
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
        return true
      rescue Errno::ENOENT => error
        raise Fig::NotFoundError.new error.message, url
      end
    else
      Fig::Logging.fatal "Unknown protocol: #{url}"
      raise Fig::NetworkError.new("Unknown protocol: #{url}")
    end
  end

  def download_resource(url, dir)
    FileUtils.mkdir_p(dir)
    download(url, File.join(dir, URI.parse(url).path.split('/').last))
  end

  def download_and_unpack_archive(url, dir)
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
      Fig::Logging.fatal "Unknown archive type: #{basename}"
      raise Fig::NetworkError.new("Unknown archive type: #{basename}")
    end
  end

  def upload(local_file, remote_file)
    Fig::Logging.debug "Uploading #{local_file} to #{remote_file}."
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
      Fig::Logging.fatal "Unknown protocol: #{uri}"
      raise Fig::NetworkError.new("Unknown protocol: #{uri}")
    end
  end

  def delete_and_recreate_directory(dir)
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
    Fig::Logging.info msg
  end

  # Expects files_to_archive as an Array of filenames.
  def create_archive(archive_name, files_to_archive)
    if Fig::OperatingSystem.java?
      `tar czvf #{archive_name} #{files_to_archive.join(' ')}`
    else
      # TODO: Need to verify files_to_archive exists.
      ::Archive.write_open_filename(
        archive_name, ::Archive::COMPRESSION_GZIP, ::Archive::FORMAT_TAR
      ) do |writer|
        files_to_archive.each do |file_name|
          writer.new_entry do |entry|
            entry.copy_lstat(file_name)
            entry.pathname = file_name
            if entry.symbolic_link?
              linked = File.readlink(file_name)
              entry.symlink = linked
            end
            writer.write_header(entry)

            if entry.regular?
              writer.write_data(open(file_name) {|f| f.binmode; f.read })
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
      if Fig::OperatingSystem.java?
        `tar xzvf #{file}`
      else
        ::Archive.read_open_filename(file) do |reader|
          while entry = reader.next_header
            reader.extract(entry)
          end
        end
      end
    end
  end

  def self.windows?
    RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
  end

  def self.java?
    RUBY_PLATFORM == 'java'
  end

  def self.unix?
    !windows?
  end

  def shell_exec(cmd)
    # Kernel#exec won't run Kernel#at_exit handlers.
    Fig::AtExit.execute()
    if ENV['FIG_COVERAGE']
      SimpleCov.at_exit.call
    end

    if Fig::OperatingSystem.windows?
      Kernel.exec(ENV['ComSpec'], '/c', cmd.join(' '))
    else
      Kernel.exec(ENV['SHELL'], '-c', cmd.join(' '))
    end
  end

  def self.wrap_variable_name_with_shell_expansion(variable_name)
    if Fig::OperatingSystem.windows?
      return "%#{variable_name}%"
    else
      return "$#{variable_name}"
    end
  end

  def self.get_environment_variables(initial_values = nil)
    if Fig::OperatingSystem.windows?
      return Fig::EnvironmentVariables::CaseInsensitive.new(initial_values)
    end

    return Fig::EnvironmentVariables::CaseSensitive.new(initial_values)
  end

  private

  # path = The local path the file should be downloaded to.
  # cmd = The command to be run on the remote host.
  def ssh_download(user, host, path, cmd)
    return_code = nil
    tempfile = Tempfile.new('tmp')
    Net::SSH.start(host, user) do |ssh|
      ssh.open_channel do |channel|
        channel.exec(cmd)
        channel.on_data() { |ch, data| tempfile << data }
        channel.on_extended_data() { |ch, type, data| Fig::Logging.error "SSH Download ERROR: #{data}" }
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
      raise Fig::NotFoundError.new 'Remote path not found', path
    when SUCCESS
      FileUtils.mv(tempfile.path, path)
      return true
    else
      tempfile.delete
      Fig::Logging.fatal "Unable to download file #{path}: #{return_code}"
      raise Fig::NetworkError.new("Unable to download file #{path}: #{return_code}")
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

  def download_via_http_get(uri_string, file, redirection_limit = 10)
    if redirection_limit < 1
      Fig::Logging.debug 'Too many HTTP redirects.'
      raise Fig::NotFoundError.new 'Too many HTTP redirects.', uri_string
    end

    response = Net::HTTP.get_response(URI(uri_string))

    case response
    when Net::HTTPSuccess then
      file.write(response.body)
    when Net::HTTPRedirection then
      location = response['location']
      Fig::Logging.debug "Redirecting to #{location}."
      download_via_http_get(location, file, limit - 1)
    else
      Fig::Logging.debug "Download failed: #{response.code} #{response.message}."
      raise Fig::NotFoundError.new(
        "Download failed: #{response.code} #{response.message}.", uri_string
      )
    end

    return
  end

  def log_download(url, path)
    Fig::Logging.debug "Downloading #{url} to #{path}."
  end
end
