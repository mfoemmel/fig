$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'rbconfig'
require 'rspec'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'fileutils'

require 'fig/command'
require 'fig/figrc'
require 'fig/logging'
require 'fig/repository'

class Popen
  def self.setup_open3
    require 'open3'
    def self.popen(*cmd)
      exit_code = nil

      Open3.popen3(*cmd) { |stdin, stdout, stderr, wait_thread|
        yield stdin, stdout, stderr

        exit_code = wait_thread.value
      }

      return exit_code
    end
  end

  if Fig::OperatingSystem.windows?
    setup_open3
  elsif Fig::OperatingSystem.java?
    setup_open3
  else
    require 'open4'
    def self.popen(*cmd)
      return Open4::popen4(*cmd) { |pid, stdin, stdout, stderr|
        yield stdin, stdout, stderr
      }
    end
  end
end

def fig(args, input = nil, no_raise_on_error = false, figrc = nil)
  Dir.chdir FIG_SPEC_BASE_DIRECTORY do
    args = "--log-level warn #{args}"
    args = "--file - #{args}" if input

    if figrc
      args = "--figrc #{figrc} #{args}"
    else
      args = "--no-figrc #{args}"
    end

    out = nil
    err = nil

    result = Popen.popen(*("#{RUBY_EXE} #{FIG_EXE} #{args}".split)) do
      |stdin, stdout, stderr|

      if input
        stdin.puts input
        stdin.close
      end

      err = stderr.read.strip
      out = stdout.read.strip
      # TODO: remove the following lines as it exists only to eat a warning specific to the grid build machines
      err = err.gsub(/(?:\/[a-zA-Z0-9. -:]+)+: warning: Insecure world writable dir (?:\/[a-zA-Z0-9. -:]+)+in PATH, mode 041777/, '')
      err = err.gsub(/(?:\/[a-zA-Z0-9. -:]+)+[a-zA-Z0-9 `'<>():]+\nIt seems your ruby installation is missing psych \(for YAML output\)\.\nTo eliminate this warning, please install libyaml and reinstall your ruby\.\n?/, '')

      # TODO: remove the following lines as it exists only to eat a warning specific to windows machines
      ruby_1_9_2_warning_regex = %r/(?:[a-zA-Z]:)?(?:\/[a-zA-Z0-9 -]+)+\.rb:\d+: warning: failed to set environment variable\. Ruby 1\.9\.3 will raise SystemCallError in this case\.?\n?/
      err = err.gsub(ruby_1_9_2_warning_regex, '').strip
      out = out.gsub(ruby_1_9_2_warning_regex, '').strip
    end


    if not result or result.success? or no_raise_on_error
      return out, err, result.nil? ? 0 : result.exitstatus
    end

    # Common scenario during development is that the fig external process will
    # fail for whatever reason, but the RSpec expectation is checking whether a
    # file was created, etc. meaning that we don't see stdout, stderr, etc. but
    # RSpec's failure message for the expectation, which isn't informative.
    # Throwing an exception that RSpec will catch will correctly integrate the
    # fig output with the rest of the RSpec output.
    fig_failure = "External fig process failed:\n"
    fig_failure << "result: #{result.nil? ? '<nil>' : result}\n"
    fig_failure << "stdout: #{out.nil? ? '<nil>' : out}\n"
    fig_failure << "stderr: #{err.nil? ? '<nil>' : err}\n"

    raise fig_failure
  end
end

Fig::Logging.initialize_post_configuration(nil, 'off', true)

FIG_SPEC_BASE_DIRECTORY =
    File.expand_path(File.dirname(__FILE__) + '/../spec/runtime-work')
FIG_HOME       = File.expand_path(FIG_SPEC_BASE_DIRECTORY + '/fighome')
FIG_REMOTE_DIR = File.expand_path(FIG_SPEC_BASE_DIRECTORY + '/remote')
FIG_REMOTE_URL = %Q<file://#{FIG_REMOTE_DIR}>
FIG_BIN        = File.expand_path(File.dirname(__FILE__) + '/../bin')
FIG_EXE        = %Q<#{FIG_BIN}/fig>

# If/when support for v1.8 gets dropped, replace this with RbConfig.ruby().
RUBY_EXE =
  [
    RbConfig::CONFIG['bindir'],
    '/',
    RbConfig::CONFIG['RUBY_INSTALL_NAME'],
    RbConfig::CONFIG['EXEEXT']
  ].join

ENV['FIG_HOME'] = FIG_HOME
ENV['FIG_REMOTE_URL'] = FIG_REMOTE_URL

def setup_test_environment()
  FileUtils.mkdir_p(FIG_SPEC_BASE_DIRECTORY)

  FileUtils.mkdir_p(FIG_HOME)

  FileUtils.mkdir_p(FIG_REMOTE_DIR)

  metadata_directory =
    File.join(FIG_REMOTE_DIR, Fig::Repository::METADATA_SUBDIRECTORY)
  FileUtils.mkdir_p(metadata_directory)

  File.open(
    File.join(FIG_REMOTE_DIR, Fig::FigRC::REPOSITORY_CONFIGURATION), 'w'
  ) do
    |handle|
    handle.puts '{}' # Empty Javascript/JSON object
  end

  return
end

def cleanup_test_environment()
  FileUtils.rm_rf(FIG_SPEC_BASE_DIRECTORY)

  return
end

def cleanup_home_and_remote()
  FileUtils.rm_rf(FIG_HOME)
  FileUtils.rm_rf(FIG_REMOTE_DIR)

  return
end

def set_local_repository_format_to_future_version()
  version_file = File.join(FIG_HOME, Fig::Repository::VERSION_FILE_NAME)
  File.open(version_file, 'w') {
    |handle| handle.write(Fig::Repository::VERSION_SUPPORTED + 1)
  }

  return
end

def set_remote_repository_format_to_future_version()
  version_file = File.join(FIG_REMOTE_DIR, Fig::Repository::VERSION_FILE_NAME)
  File.open(version_file, 'w') {
    |handle| handle.write(Fig::Repository::VERSION_SUPPORTED + 1)
  }

  return
end
