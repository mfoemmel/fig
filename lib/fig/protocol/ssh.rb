require 'fileutils'
require 'net/sftp'
require 'net/ssh'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/protocol'
require 'fig/url'

module Fig; end
module Fig::Protocol; end

# File transfers via SSH
class Fig::Protocol::SSH
  include Fig::Protocol

  def download_list(uri)
    packages = []
    Net::SSH.start(uri.host, uri.user) do |ssh|
      ls = ssh.exec!("[ -d #{uri.path} ] && find #{uri.path}")
      strip_paths_for_list(ls, packages, uri.path)
    end

    return packages
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path)
    # TODO need better way to do conditional download
    timestamp = ::File.exist?(path) ? ::File.mtime(path).to_i : 0
    # Requires that remote installation of fig be at the same location as the local machine.
    command = `which fig-download`.strip + " #{timestamp} #{uri.path}"
    log_download(uri, path)
    ssh_download(uri.user, uri.host, path, command)
  end

  def upload(local_file, uri)
    ssh_upload(uri.user, uri.host, local_file, uri)
  end

  private

  SUCCESS = 0
  NOT_MODIFIED = 3
  NOT_FOUND = 4

  # path = The local path the file should be downloaded to.
  # command = The command to be run on the remote host.
  def ssh_download(user, host, path, command)
    return_code = nil
    tempfile = Tempfile.new('tmp')
    Net::SSH.start(host, user) do |ssh|
      ssh.open_channel do |channel|
        channel.exec(command)
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
      raise Fig::FileNotFoundError.new 'Remote path not found', path
    when SUCCESS
      FileUtils.mv(tempfile.path, path)
      return true
    else
      tempfile.delete
      Fig::Logging.fatal "Unable to download file #{path}: #{return_code}"
      raise Fig::NetworkError.new("Unable to download file #{path}: #{return_code}")
    end
  end

  def ssh_upload(user, host, local_file, uri)
    dir = uri.path[0, uri.path.rindex('/')]
    Net::SSH.start(host, user) do |ssh|
      ssh.exec!("mkdir -p #{dir}")
    end
    Net::SFTP.start(host, user) do |sftp|
      sftp.upload!(local_file, uri.path)
    end
  end
end
