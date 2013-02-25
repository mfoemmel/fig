require 'stringio'

require 'fig/operating_system'

module Fig; end

class Fig::ExternalProgram
  def self.set_up_open3
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
    set_up_open3
  else
    require 'open4'
    def self.popen(*cmd)
      return Open4::popen4(*cmd) { |pid, stdin, stdout, stderr|
        yield stdin, stdout, stderr
      }
    end
  end

  def self.capture(command_line, input = nil)
    output = nil
    errors = nil

    result = popen(*command_line) do
      |stdin, stdout, stderr|

      if ! input.nil?
        stdin.puts input # Potential deadlock if input is bigger than pipe size.
      end
      stdin.close

      output = StringIO.new
      errors = StringIO.new
      input_to_output = {stdout => output, stderr => errors}
      while ! input_to_output.empty?
        ready, * = IO.select input_to_output.keys
        ready.each do
          |handle|

          begin
            input_to_output[handle] << handle.readpartial(4096)
          rescue EOFError
            input_to_output.delete handle
          end
        end
      end
    end

    if ! output.nil?
      output = output.string
    end
    if ! errors.nil?
      errors = errors.string
    end

    return output, errors, result
  end
end
