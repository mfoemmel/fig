require 'cgi'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/protocol'

module Fig; end
module Fig::Protocol; end

# File transfers using external ssh and scp programs
class Fig::Protocol::SSH
  include Fig::Protocol

  # Execute command on remote host with external ssh program
  def ssh(host, command)
    ssh_command = ['ssh', '-n', host, command]
    begin
      output, errors, result = Fig::ExternalProgram.capture ssh_command
    rescue Errno::ENOENT => error
      Fig::Logging.warn(
        %Q<Could not run "#{ssh_command.join ' '}": #{error.message}.>
      )
      return
    end

    if result && ! result.success?
      Fig::Logging.debug(
        %Q<Could not run "#{ssh_command.join ' '}": #{result}: #{errors}>
      )
      return
    end

    return output
  end

  # Use external scp program to copy a file
  def scp(from, to)
    command = ['scp', from, to]
    begin
      output, errors, result = Fig::ExternalProgram.capture command
    rescue Errno::ENOENT => error
      Fig::Logging.warn(
        %Q<Could not run "#{command.join ' '}": #{error.message}.>
      )
      return
    end

    if result && ! result.success?
      Fig::Logging.debug(
        %Q<Could not run "#{command.join ' '}": #{result}: #{errors}>
      )
      return
    end

    return output
  end

  def download_list(uri)
    packages = []
    unescaped_path = CGI.unescape uri.path

    ls = ssh(uri.host, "find '#{unescaped_path}'")
    if ls.nil?
      return packages
    end

    strip_paths_for_list(ls, packages, unescaped_path)

    return packages
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path, prompt_for_login)
    unescaped_path = CGI.unescape uri.path

    size_mtime = ssh(uri.host, "stat --format='%s %Z' '#{unescaped_path}'")
    if size_mtime.nil?
      raise Fig::FileNotFoundError.new "Unable to get size and mtime for remote path #{path}", uri
    end

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

    if scp("#{uri.host}:#{unescaped_path}", path).nil?
      raise Fig::FileNotFoundError.new "Unable to copy remote file to #{path}", uri
    end

    return true
  end

  def upload(local_file, uri)
    unescaped_path = CGI.unescape uri.path

    if ssh(uri.host, "mkdir -p '#{::File.dirname(unescaped_path)}'").nil?
      raise Fig::FileNotFoundError.new "Unable to create directory on remote", uri
    end

    if scp(local_file, "#{uri.host}:#{unescaped_path}").nil?
      raise Fig::FileNotFoundError.new "Unable to copy #{local_file} to remote", uri
    end

    return
  end
end
