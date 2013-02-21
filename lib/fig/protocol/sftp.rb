require 'net/sftp'

require 'fig/logging'
require 'fig/network_error'
require 'fig/package_descriptor'
require 'fig/protocol'
require 'fig/protocol/netrc_enabled'

module Fig; end
module Fig::Protocol; end

# File transfers via SFTP
class Fig::Protocol::SFTP
  include Fig::Protocol
  include Fig::Protocol::NetRCEnabled

  def download_list(uri)
    package_versions = []

    sftp_run(uri) do
      |connection|

      connection.dir.foreach uri.path do
        |package_directory|

        if package_directory.directory?
          package_name = package_directory.name

          if package_name =~ Fig::PackageDescriptor::COMPONENT_PATTERN
            connection.dir.foreach "#{uri.path}/#{package_name}" do
              |version_directory|

              if version_directory.directory?
                version_name = version_directory.name

                if version_name =~ Fig::PackageDescriptor::COMPONENT_PATTERN
                  package_versions << "#{package_name}/#{version_name}"
                end
              end
            end
          end
        end
      end
    end

    return package_versions
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(uri, path)
    sftp_run(uri) do
      |connection|

      return connection.stat!(uri.path).mtime.to_f <= ::File.mtime(path).to_f
    end

    return nil
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path)
    sftp_run(uri) do
      |connection|

      begin
        # *sigh* Always call #stat!(), even if the local file does not exist
        # because #download!() throws Strings and not proper exception objects
        # when the remote path does not exist.
        stat = connection.stat!(uri.path)

        if ::File.exist?(path) && stat.mtime.to_f <= ::File.mtime(path).to_f
          Fig::Logging.debug "#{path} is up to date."
          return false
        else
          log_download uri, path
          connection.download! uri.path, path

          return true
        end
      rescue Net::SFTP::StatusException => error
        if error.code == Net::SFTP::Constants::StatusCodes::FX_NO_SUCH_FILE
          raise Fig::FileNotFoundError.new(error.message, uri)
        end
        raise error
      end
    end

    return
  end

  def upload(local_file, uri)
    sftp_run(uri) do
      |connection|

      ensure_directory_exists connection, ::File.dirname(uri.path)
      connection.upload! local_file, uri.path
    end

    return
  end

  private

  def sftp_run(uri, &block)
    host = uri.host

    load_authentication_for host

    begin
      options = {:password => get_password}
      port = uri.port
      if port
        options[:port] = port
      end

      Net::SFTP.start(host, get_username, options, &block)
    rescue Net::SSH::Exception => error
      raise Fig::NetworkError.new error.message
    rescue Net::SFTP::Exception => error
      raise Fig::NetworkError.new error.message
    end

    return
  end

  def ensure_directory_exists(connection, path)
    begin
      connection.lstat!(path)
      return
    rescue Net::SFTP::StatusException => error
      if error.code != Net::SFTP::Constants::StatusCodes::FX_NO_SUCH_FILE
        raise Fig::NetworkError.new(
          "Could not stat #{path}: #{response.message} (#{response.code})"
        )
      end
    end

    if path == '/'
      raise Fig::NetworkError.new 'Root path does not exist.'
    end

    ensure_directory_exists connection, ::File.dirname(path)

    connection.mkdir! path

    return
  end
end
