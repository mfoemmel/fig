require 'cgi'
require 'fileutils'
# Must specify absolute path of ::Archive when using
# this module to avoid conflicts with Fig::Statement::Archive
require 'libarchive_ruby'
require 'rbconfig'

require 'fig/at_exit'
require 'fig/environment_variables/case_insensitive'
require 'fig/environment_variables/case_sensitive'
require 'fig/logging'
require 'fig/network_error'
require 'fig/protocol/file'
require 'fig/protocol/ftp'
require 'fig/protocol/http'
require 'fig/protocol/sftp'
require 'fig/repository_error'
require 'fig/url'
require 'fig/user_input_error'

module Fig; end

# Does things requiring real O/S interaction, primarilly taking care of file
# transfers and running external commands.
class Fig::OperatingSystem
  WINDOWS_FILE_NAME_ILLEGAL_CHARACTERS = %w[ \\ / : * ? " < > | ]
  UNIX_FILE_NAME_ILLEGAL_CHARACTERS    = %w[ / ]

  def self.windows?
    return !! (RbConfig::CONFIG['host_os'] =~ /mswin|mingw/)
  end

  def self.unix?
    ! Fig::OperatingSystem.windows?
  end

  def self.absolute?(path)
    return (
          path =~ %r< ^ [\\/] >x \
      ||  Fig::OperatingSystem.windows? && path =~ %r< ^ [a-z] : >xi
    )
  end

  def self.file_name_illegal_characters()
    if Fig::OperatingSystem.windows?
      return WINDOWS_FILE_NAME_ILLEGAL_CHARACTERS
    end

    return UNIX_FILE_NAME_ILLEGAL_CHARACTERS
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

  def initialize(login)
    @protocols = {}
    @protocols['file'] = Fig::Protocol::File.new
    @protocols['ftp']  = Fig::Protocol::FTP.new login
    @protocols['http'] = Fig::Protocol::HTTP.new
    @protocols['sftp'] = Fig::Protocol::SFTP.new
  end

  def list(dir)
    Dir.entries(dir) - ['.', '..']
  end

  def mtime(path)
    File.mtime(path)
  end

  def write(path, content)
    File.open(path, 'wb') { |f| f.binmode; f << content }
  end

  def download_list(url)
    begin
      protocol, uri = decode_protocol url

      return protocol.download_list uri
    rescue SocketError => error
      Fig::Logging.debug error.message
      raise Fig::NetworkError.new "#{url}: #{error.message}"
    rescue Errno::ETIMEDOUT => error
      Fig::Logging.debug error.message
      raise Fig::NetworkError.new "#{url}: #{error.message}"
    end
  end

  # Determine whether we need to update something.  Returns nil to indicate
  # "don't know".
  def path_up_to_date?(url, path, prompt_for_login)
    return false if ! File.exist? path

    protocol, uri = decode_protocol url
    return protocol.path_up_to_date? uri, path, prompt_for_login
  end

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(url, path, prompt_for_login)
    protocol, uri = decode_protocol url

    FileUtils.mkdir_p(File.dirname path)

    return protocol.download uri, path, prompt_for_login
  end

  # Returns the basename and full path to the download.
  def download_resource(url, download_directory)
    FileUtils.mkdir_p(download_directory)

    basename = CGI.unescape Fig::URL.parse(url).path.split('/').last
    path     = File.join(download_directory, basename)

    download(url, path, false)

    return basename, path
  end

  def download_and_unpack_archive(url, download_directory, unpack_directory)
    basename, path = download_resource(url, download_directory)

    case path
    when /\.tar\.gz$/
      unpack_archive(unpack_directory, path)
    when /\.tgz$/
      unpack_archive(unpack_directory, path)
    when /\.tar\.bz2$/
      unpack_archive(unpack_directory, path)
    when /\.zip$/
      unpack_archive(unpack_directory, path)
    else
      Fig::Logging.fatal "Unknown archive type: #{basename}"
      raise Fig::NetworkError.new("Unknown archive type: #{basename}")
    end

    return
  end

  def upload(local_file, remote_file)
    Fig::Logging.debug "Uploading #{local_file} to #{remote_file}."


    protocol, uri = decode_protocol remote_file
    protocol.upload local_file, uri

    return
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
      if ! File.exist?(target) || File.mtime(source) != File.mtime(target)
        Fig::Logging.info "#{msg} #{target}" if msg
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)
        File.utime(File.atime(source), File.mtime(source), target)
      end
    end
  end

  def move_file(directory, from, to)
    Dir.chdir(directory) { FileUtils.mv(from, to, :force => true) }
  end

  # Expects files_to_archive as an Array of filenames.
  def create_archive(archive_name, files_to_archive)
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

  # This method can handle the following archive types:
  # .tar.bz2
  # .tar.gz
  # .tgz
  # .zip
  def unpack_archive(directory, archive_path)
    FileUtils.mkdir_p directory
    Dir.chdir(directory) do
      if ! File.exists? archive_path
        raise Fig::RepositoryError.new "#{archive_path} does not exist."
      end

      running_on_windows = Fig::OperatingSystem.windows?
      ::Archive.read_open_filename(archive_path) do |reader|
        while entry = reader.next_header
          if running_on_windows
            check_archive_entry_for_windows entry, archive_path
          end

          begin
            reader.extract(entry)
          rescue Archive::Error => exception
            # Nice how the error message doesn't include any information about
            # what was having the problem.
            message = exception.message.sub(/^Extract archive failed: /, '')
            new_exception =
              Fig::RepositoryError.new(
                "Could not extract #{entry.pathname} from #{archive_path}: #{message}"
              )

            new_exception.set_backtrace exception.backtrace
            raise new_exception
          end
        end
      end
    end
  end

  def shell_exec(command)
    if Fig::OperatingSystem.windows?
      plain_exec [ ENV['ComSpec'],            '/c', command ]
    else
      plain_exec [ ENV['SHELL'] || '/bin/sh', '-c', command ]
    end
  end

  def plain_exec(command)
    # Kernel#exec won't run Kernel#at_exit handlers.
    Fig::AtExit.execute()
    if ENV['FIG_COVERAGE']
      SimpleCov.at_exit.call
    end

    begin
      Kernel.exec(*command)
    rescue SystemCallError => exception
      raise Fig::UserInputError.new exception
    end
  end

  # *sigh* Apparently Ruby < v1.9.3 does some wacko thing with single argument
  # exec that causes it to not invoke the shell, so we've got this mess.
  def plain_or_shell_exec(command)
    if command.size > 1
      plain_exec(command)
    else
      shell_exec(command[0])
    end
  end

  private

  def decode_protocol(url)
    uri = Fig::URL.parse(url)
    protocol = @protocols[uri.scheme]
    raise_unknown_protocol(url) if protocol.nil?

    return protocol, uri
  end

  def check_archive_entry_for_windows(entry, archive_path)
    bad_type = nil
    if entry.symbolic_link?
      bad_type = 'symbolic link'
    elsif entry.block_special?
      bad_type = 'block device'
    elsif entry.character_special?
      bad_type = 'character device'
    elsif entry.fifo?
      bad_type = 'pipe'
    elsif entry.socket?
      bad_type = 'socket'
    end

    if bad_type
      raise Fig::RepositoryError.new(
        "Could not extract #{entry.pathname} from #{archive_path} because it is a #{bad_type}."
      )
    end

    return
  end

  def raise_unknown_protocol(url)
    Fig::Logging.fatal %Q<Don't know how to handle the protocol in "#{url}".>
    raise Fig::NetworkError.new(
      %Q<Don't know how to handle the protocol in "#{url}".>
    )

    return
  end
end
