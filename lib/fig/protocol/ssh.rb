require 'cgi'

require 'fig/logging'
require 'fig/network_error'
require 'fig/protocol'

module Fig; end
module Fig::Protocol; end

# File transfers using external ssh and scp programs
class Fig::Protocol::SSH
  include Fig::Protocol

  def download_list(uri)
    packages = []
    unescaped_path = CGI.unescape uri.path

    ls = ssh(uri.host, 'find', unescaped_path) {
      |error_message|

      raise Fig::NetworkError.new error_message
    }

    strip_paths_for_list(ls, packages, unescaped_path)

    return packages
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path, prompt_for_login)
    unescaped_path = CGI.unescape uri.path

    size_mtime = ssh(uri.host, 'stat', '--format=%s %Z', unescaped_path) {
      |error_message|

      raise Fig::NetworkError.new(
        "Unable to get size and modification time for remote path #{path}: #{error_message}",
      )
    }

    remote_size, remote_mtime = size_mtime.split
    remote_size  = remote_size.to_i
    remote_mtime = remote_mtime.to_i

    if remote_size != ::File.size(path)
      return false
    end

    if remote_mtime <= ::File.mtime(path).to_i
      return true
    end

    return false
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path, prompt_for_login)
    unescaped_path = CGI.unescape uri.path

    scp("#{uri.host}:#{unescaped_path}", path) {
      |error_message|

      raise Fig::NetworkError.new(
        "Unable to copy remote file to #{path}: #{error_message}",
      )
    }

    return true
  end

  def upload(local_file, uri)
    unescaped_path = CGI.unescape uri.path

    ssh(uri.host, 'mkdir', '-p', ::File.dirname(unescaped_path)) {
      |error_message|

      raise Fig::NetworkError.new(
        "Unable to create directory on remote: #{error_message}",
      )
    }

    scp(local_file, "#{uri.host}:#{unescaped_path}") {
      |error_message|

      raise Fig::NetworkError.new(
        "Unable to copy #{local_file} to remote: #{error_message}",
      )
    }

    return
  end

  private

  # Execute command on remote host with external ssh program.
  def ssh(host, *command, &error_block)
    ssh_command = ['ssh', '-n', host, *command]
    begin
      output, errors, result = Fig::ExternalProgram.capture ssh_command
    rescue Errno::ENOENT => error
      yield %Q<Could not run "#{ssh_command.join ' '}": #{error.message}.>

      return
    end

    if result && ! result.success?
      yield %Q<Could not run "#{ssh_command.join ' '}": #{result}: #{errors}>

      return
    end

    return output
  end

  # Use external scp program to copy a file.
  def scp(from, to, &error_block)
    command = ['scp', from, to]
    begin
      output, errors, result = Fig::ExternalProgram.capture command
    rescue Errno::ENOENT => error
      yield %Q<Could not run "#{command.join ' '}": #{error.message}.>

      return
    end

    if result && ! result.success?
      yield %Q<Could not run "#{command.join ' '}": #{result}: #{errors}>

      return
    end

    return output
  end
end
