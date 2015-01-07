# coding: utf-8

require 'cgi'
require 'fileutils'
require 'find'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/protocol'

module Fig; end
module Fig::Protocol; end

# File transfers for the local filesystem.
class Fig::Protocol::File
  include Fig::Protocol

  def download_list(uri)
    packages = []
    unescaped_path = CGI.unescape uri.path
    return packages if ! ::File.exist?(unescaped_path)

    ls = ''
    Find.find(unescaped_path) {
      |file|

      if FileTest.directory? file
        ls << file.to_s
        ls << "\n"
      end
    }

    strip_paths_for_list(ls, packages, unescaped_path)

    return packages
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path, prompt_for_login)
    begin
      unescaped_path = CGI.unescape uri.path
      if ::File.size(unescaped_path) != ::File.size(path)
        return false
      end

      if ::File.mtime(unescaped_path) <= ::File.mtime(path)
        return true
      end

      return false
    rescue Errno::ENOENT => error
      raise Fig::FileNotFoundError.new error.message, uri
    end
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path, prompt_for_login)
    begin
      unescaped_path = CGI.unescape uri.path
      FileUtils.cp(unescaped_path, path)

      return true
    rescue Errno::ENOENT => error
      raise Fig::FileNotFoundError.new error.message, uri
    end
  end

  def upload(local_file, uri)
    unescaped_path = CGI.unescape uri.path
    FileUtils.mkdir_p(::File.dirname(unescaped_path))
    FileUtils.cp(local_file, unescaped_path)

    return
  end
end
