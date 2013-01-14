require 'net/ftp'
require 'net/netrc'

require 'highline/import'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/protocol'
require 'fig/url'

module Fig; end
module Fig::Protocol; end

# File transfers via FTP
class Fig::Protocol::FTP
  include Fig::Protocol

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

  def download_list(uri)
    ftp = Net::FTP.new(uri.host)
    ftp_login(ftp, uri.host)
    ftp.chdir(uri.path)
    dirs = ftp.nlst
    ftp.close

    download_ftp_list(uri, dirs)
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path)
    begin
      ftp = Net::FTP.new(uri.host)
      ftp_login(ftp, uri.host)

      if ftp.mtime(uri.path) <= File.mtime(path)
        return true
      end

      return false
    rescue Net::FTPPermError => error
      Fig::Logging.debug error.message
      raise Fig::FileNotFoundError.new error.message, uri
    rescue SocketError => error
      Fig::Logging.debug error.message
      raise Fig::FileNotFoundError.new error.message, uri
    end
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path)
    begin
      ftp = Net::FTP.new(uri.host)
      ftp_login(ftp, uri.host)

      if File.exist?(path) && ftp.mtime(uri.path) <= File.mtime(path)
        Fig::Logging.debug "#{path} is up to date."
        return false
      else
        log_download(uri, path)
        ftp.getbinaryfile(uri.path, path, 256*1024)
        return true
      end
    rescue Net::FTPPermError => error
      Fig::Logging.debug error.message
      raise Fig::FileNotFoundError.new error.message, uri
    rescue SocketError => error
      Fig::Logging.debug error.message
      raise Fig::FileNotFoundError.new error.message, uri
    rescue Errno::ETIMEDOUT => error
      Fig::Logging.debug error.message
      raise Fig::FileNotFoundError.new error.message, uri
    end
  end

  def upload(local_file, uri)
    ftp_uri = Fig::URL.parse(ENV['FIG_REMOTE_URL'])
    ftp_root_path = ftp_uri.path
    ftp_root_dirs = ftp_uri.path.split('/')
    remote_publish_path = uri.path[0, uri.path.rindex('/')]
    remote_publish_dirs = remote_publish_path.split('/')
    # Use array subtraction to deduce which project/version folder to upload
    # to, i.e. [1,2,3] - [2,3,4] = [1]
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
  end

  private

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
end
