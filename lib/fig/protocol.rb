require 'fig/logging'
require 'fig/network_error'

module Fig; end

# File transfers.
module Fig::Protocol
  def download_list(uri)
    Fig::Logging.fatal "Protocol not supported: #{uri}"
    raise Fig::NetworkError.new "Protocol not supported: #{uri}"
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path)
    return nil # Not implemented
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path)
    Fig::Logging.fatal "Protocol not supported: #{uri}"
    raise Fig::NetworkError.new "Protocol not supported: #{uri}"
  end

  def upload(local_file, uri)
    Fig::Logging.fatal "Protocol not supported: #{uri}"
    raise Fig::NetworkError.new "Protocol not supported: #{uri}"
  end

  private

  def strip_paths_for_list(ls_output, packages, path)
    if not ls_output.nil?
      ls_output = ls_output.gsub(path + '/', '').gsub(path, '').split("\n")
      ls_output.each do |line|
        parts =
          line.gsub(/\\/, '/').sub(/^\.\//, '').sub(/:$/, '').chomp().split('/')
        packages << parts.join('/') if parts.size == 2
      end
    end
  end

  def log_download(uri, path)
    Fig::Logging.debug "Downloading #{uri} to #{path}."
  end
end
