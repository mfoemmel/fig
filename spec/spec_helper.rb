$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'fileutils'

require 'fig'
require 'fig/logging'

class Popen
  if Fig::OS.windows?
    require 'win32/open3'
    def self.popen(*cmd)
      Open3.popen3(*cmd) { |stdin,stdout,stderr|
        yield stdin, stdout, stderr
      }
    end
  elsif Fig::OS.java?
    require 'open3'
    def self.popen(*cmd)
      Open3.popen3(*cmd) { |stdin,stdout,stderr|
        yield stdin, stdout, stderr
      }
    end
  else
    require 'open4'
    def self.popen(*cmd)
      Open4::popen4(*cmd) { |pid, stdin, stdout, stderr|
        yield stdin, stdout, stderr
      }
    end
  end
end

def fig(args, input = nil, no_raise_on_error = false)
  Dir.chdir FIG_SPEC_BASE_DIRECTORY do
    args = "--log-level warn #{args}"
    args = "--no-figrc #{args}"
    args = "--file - #{args}" if input
    out = nil
    err = nil
    Popen.popen("#{Gem::Platform::RUBY} #{FIG_EXE} #{args}") do
      |stdin, stdout, stderr|

      if input
        stdin.puts input
        stdin.close
      end

      err = stderr.read.strip
      out = stdout.read.strip
    end
    result = $CHILD_STATUS

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

def setup_repository()
  return if self.class.const_defined? :FIG_SPEC_BASE_DIRECTORY

  self.class.const_set(
    :FIG_SPEC_BASE_DIRECTORY,
    File.expand_path(File.dirname(__FILE__) + '/../spec/runtime-work')
  )
  FileUtils.mkdir_p(FIG_SPEC_BASE_DIRECTORY)

  self.class.const_set(
    :FIG_HOME, File.expand_path(FIG_SPEC_BASE_DIRECTORY + '/fighome')
  )
  FileUtils.mkdir_p(FIG_HOME)
  ENV['FIG_HOME'] = FIG_HOME

  self.class.const_set(
    :FIG_REMOTE_DIR, File.expand_path(FIG_SPEC_BASE_DIRECTORY + '/remote')
  )
  FileUtils.mkdir_p(FIG_REMOTE_DIR)
  FileUtils.mkdir_p(File.join(FIG_REMOTE_DIR,'_meta'))
  ENV['FIG_REMOTE_URL'] = %Q<file://#{FIG_REMOTE_DIR}>

  self.class.const_set(
    :FIG_BIN,
    File.expand_path(File.dirname(__FILE__) + '/../bin')
  )
  ENV['PATH'] = FIG_BIN + ':' + ENV['PATH']  # To find the correct fig-download
  self.class.const_set(:FIG_EXE, %Q<#{FIG_BIN}/fig>)
end
