require 'cgi'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/protocol'

module Fig; end
module Fig::Protocol; end

# File transfers for the local filesystem.
class Fig::Protocol::SSH
  include Fig::Protocol

  def logged_system(cmd)
    Fig::Logging.debug "system: #{cmd}"
    out = `#{cmd} 2>&1`.strip
    if $?.exitstatus != 0
      Fig::Logging.debug "  Error: #{out}"
      return nil
    end
    return out
  end

  def download_list(uri)
    packages = []
    unescaped_path = CGI.unescape uri.path

    ls = logged_system("ssh #{uri.host} \"find '#{unescaped_path}'\"")
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

    size_mtime = logged_system("ssh #{uri.host} \"stat --format='%s %Z' '#{unescaped_path}'\"")
    if size_mtime.nil?
      raise Fig::FileNotFoundError.new "Error, see --log-level=debug for details.", uri
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

    if logged_system("scp '#{uri.host}:#{unescaped_path}' '#{path}'").nil?
      raise Fig::FileNotFoundError.new "Error, see --log-level=debug for details.", uri
    end

    return true
  end

  def upload(local_file, uri)
    unescaped_path = CGI.unescape uri.path

    if logged_system("ssh #{uri.host} \"mkdir -p '#{::File.dirname(unescaped_path)}'").nil?
      raise Fig::FileNotFoundError.new "Error, see --log-level=debug for details.", uri
    end

    if logged_system("scp '#{local_file}' '#{uri.host}:#{unescaped_path}'").nil?
      raise Fig::FileNotFoundError.new "Error, see --log-level=debug for details.", uri
    end

    return
  end
end
