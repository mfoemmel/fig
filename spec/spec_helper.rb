$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

if ENV['FIG_COVERAGE']
  require 'simplecov' # note that .simplecov will be loaded here.

  SimpleCov.start
end

require 'rubygems'
require 'rbconfig'
require 'rspec'

require 'fileutils'

require 'fig/command'
require 'fig/figrc'
require 'fig/logging'
require 'fig/repository'

FIG_SPEC_BASE_DIRECTORY =
  File.expand_path(File.dirname(__FILE__) + '/../spec/runtime-work')
USER_HOME         = FIG_SPEC_BASE_DIRECTORY + '/userhome'
FIG_HOME          = FIG_SPEC_BASE_DIRECTORY + '/fighome'
FIG_REMOTE_DIR    = FIG_SPEC_BASE_DIRECTORY + '/remote'
FIG_REMOTE_URL    = %Q<file://#{FIG_REMOTE_DIR}>

# Ruby v1.8 won't let you do "CONSTANT ||= whatever".
self.class.const_defined? :FIG_DIRECTORY or
  self.class.const_set(
    :FIG_DIRECTORY, File.expand_path(File.dirname(__FILE__)) + '/../bin'
  )
self.class.const_defined? :FIG_COMMAND_CLASS or
  self.class.const_set :FIG_COMMAND_CLASS, Fig::Command

FIG_PROGRAM       =
self.class.const_defined?(:FIG_PROGRAM) ||
  self.class.const_set(
    :FIG_PROGRAM,
    %Q<#{FIG_DIRECTORY}/fig#{ENV['FIG_SPEC_DEBUG'] ? '-debug' : ''}>
  )

# Needed for testing of resources.
FIG_FILE_GUARANTEED_TO_EXIST =
  File.expand_path(FIG_SPEC_BASE_DIRECTORY + '/file-guaranteed-to-exist')

# If/when support for v1.8 gets dropped, replace this with RbConfig.ruby().
RUBY_EXE =
  [
    RbConfig::CONFIG['bindir'],
    '/',
    RbConfig::CONFIG['RUBY_INSTALL_NAME'],
    RbConfig::CONFIG['EXEEXT']
  ].join

self.class.const_defined? :BASE_FIG_COMMAND_LINE or
  self.class.const_set :BASE_FIG_COMMAND_LINE, [RUBY_EXE, FIG_PROGRAM]

ENV['HOME']           = USER_HOME
ENV['FIG_HOME']       = FIG_HOME
ENV['FIG_REMOTE_URL'] = FIG_REMOTE_URL
ENV['FIG_COVERAGE_ROOT_DIRECTORY'] =
  File.expand_path(File.dirname(__FILE__) + '/..')

# TODO: remove this once v1 is done.
ENV['FIG_ALLOW_NON_V0_GRAMMAR'] = 'yes'

Fig::Logging.initialize_post_configuration(nil, 'off', true)

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

$fig_run_count = 0 # Nasty, nasty global.

# Options:
#
#   :current_directory  What the current directory should be when starting fig.
#
#   :figrc              Value of the --figrc option.  If not specified,
#                       --no-figrc will be passed to fig.
#
#   :no_raise_on_error  Normally an exception is thrown if fig returns an error
#                       code.  If this option is true, then no exception will
#                       be raised, allowing testing of failure states/output.
#
#   :fork               If specified as false, don't run fig as an external
#                       process, but in-process instead.  This will run faster,
#                       but will screw up the test suite if fig invokes
#                       Kernel#exec (due to a command statement) or otherwise
#                       depends upon at-exit behavior.
def fig(command_line, first_extra = nil, rest_extra = nil)
  input, options = _fig_input_options(first_extra, rest_extra)

  $fig_run_count += 1
  ENV['FIG_COVERAGE_RUN_COUNT'] = $fig_run_count.to_s

  out = err = exit_code = nil

  current_directory = options[:current_directory] || FIG_SPEC_BASE_DIRECTORY
  Dir.chdir current_directory do
    standard_options = []
    standard_options.concat %w< --log-level warn >
    standard_options.concat %w< --file - > if input

    figrc = options[:figrc]
    if figrc
      standard_options << '--figrc' << figrc
    else
      standard_options << '--no-figrc'
    end

    if command_line.include?('--update-lock-response')
      if ! options.fetch(:fork, true)
        raise 'Cannot specify both ":fork => false" and --update-lock-response.'
      end
    elsif ! options.fetch(:fork, true) || Fig::OperatingSystem.windows?
      standard_options.concat %w< --update-lock-response ignore >
    end

    command_line = [standard_options, command_line].flatten
    out, err, exit_code = _run_command command_line, input, options
  end

  return out, err, exit_code
end

# A bit of ruby magic to make invoking fig() nicer; this takes advantage of the
# hash assignment syntax so you can call it like any of
#
#     fig([arguments])
#     fig([arguments], input)
#     fig([arguments], input, :no_raise_on_error => true)
#     fig([arguments], :no_raise_on_error => true)
def _fig_input_options(first_extra, rest_extra)
  return nil, rest_extra || {} if first_extra.nil?

  if first_extra.is_a? Hash
    return nil, first_extra
  end

  return first_extra, rest_extra || {}
end

def _run_command(command_line, input, options)
  out = err = exit_code = exit_string = nil

  if options.fetch(:fork, true)
    out, err, exit_code, exit_string =
      _run_command_externally command_line, input, options
  else
    out, err, exit_code, exit_string =
      _run_command_internally command_line, input, options
  end

  if exit_string
    # Common scenario during development is that the fig process will fail for
    # whatever reason, but the RSpec expectation is checking whether a file was
    # created, etc. meaning that we don't see stdout, stderr, etc. but RSpec's
    # failure message for the expectation, which isn't informative.  Throwing
    # an exception that RSpec will catch will correctly integrate the fig
    # output with the rest of the RSpec output.
    fig_failure = "Fig process failed:\n"
    fig_failure << "command: #{command_line.join(' ')}\n"
    fig_failure << "result: #{exit_string}\n"
    fig_failure << "stdout: #{out.nil? ? '<nil>' : out}\n"
    fig_failure << "stderr: #{err.nil? ? '<nil>' : err}\n"
    if input
      fig_failure << "input: #{input}\n"
    end

    raise fig_failure
  end

  if ! options[:dont_strip_output]
    err.strip!
    out.strip!
  end

  return out, err, exit_code
end

def _run_command_externally(command_line, input, options)
  out = nil
  err = nil

  full_command_line = BASE_FIG_COMMAND_LINE + command_line
  result = Popen.popen(*full_command_line) do
    |stdin, stdout, stderr|

    if input
      stdin.puts input
      stdin.close
    end

    err = stderr.read
    out = stdout.read
  end

  exit_code   = result.nil? ? 0 : result.exitstatus
  exit_string = nil
  if result && ! result.success? && ! options[:no_raise_on_error]
    exit_string = result.to_s
  end

  return out, err, exit_code, exit_string
end

def _run_command_internally(command_line, input, options)
  original_stdin  = $stdin
  original_stdout = $stdout
  original_stderr = $stderr

  begin
    stdin     = input ? StringIO.new(input) : StringIO.new
    stdout    = StringIO.new
    stderr    = StringIO.new
    exit_code = nil

    $stdin  = stdin
    $stdout = stdout
    $stderr = stderr

    if ENV['FIG_SPEC_DEBUG']
      exit_code = FIG_COMMAND_CLASS.new.run_fig command_line
    else
      exit_code =
        FIG_COMMAND_CLASS.new.run_fig_with_exception_handling command_line
    end

    exit_string = nil
    if exit_code != 0 && ! options[:no_raise_on_error]
      exit_string = exit_code.to_s
    end

    return stdout.string, stderr.string, exit_code, exit_string
  ensure
    $stdin  = original_stdin
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

def set_up_test_environment()
  FileUtils.mkdir_p(FIG_SPEC_BASE_DIRECTORY)
  FileUtils.mkdir_p(USER_HOME)
  FileUtils.mkdir_p(FIG_HOME)
  FileUtils.mkdir_p(FIG_REMOTE_DIR)

  FileUtils.touch(FIG_FILE_GUARANTEED_TO_EXIST)

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

def clean_up_test_environment()
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
  FileUtils.mkdir_p(FIG_HOME)
  File.open(version_file, 'w') {
    |handle| handle.write(Fig::Repository::VERSION_SUPPORTED + 1)
  }

  return
end

def set_remote_repository_format_to_future_version()
  version_file = File.join(FIG_REMOTE_DIR, Fig::Repository::VERSION_FILE_NAME)
  FileUtils.mkdir_p(FIG_REMOTE_DIR)
  File.open(version_file, 'w') {
    |handle| handle.write(Fig::Repository::VERSION_SUPPORTED + 1)
  }

  return
end

# IO.write() only exists in ruby v1.9.3+. *sigh*
def write_file(path, content)
  File.open(path, 'w') { |handle| handle << content }
end
