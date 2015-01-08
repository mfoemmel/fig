# coding: utf-8

require 'stringio'

require 'fig/operating_system'

module Fig; end

class Fig::ExternalProgram
  def self.popen(*cmd)
    exit_code = nil

    options = {}
    stdin_read, stdin_write = IO.pipe Encoding::UTF_8
    options[:in] = stdin_read
    stdin_write.sync = true

    stdout_read, stdout_write = IO.pipe Encoding::UTF_8
    options[:out] = stdout_write

    stderr_read, stderr_write = IO.pipe Encoding::UTF_8
    options[:err] = stderr_write

    popen_run(
      cmd,
      options,
      [stdin_read, stdout_write, stderr_write],
      [stdin_write, stdout_read, stderr_read],
    ) do
      |stdin, stdout, stderr, wait_thread|

      yield stdin, stdout, stderr

      exit_code = wait_thread.value
    end

    return exit_code
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

  private

  # Stolen from open3.rb
  def self.popen_run(cmd, opts, child_io, parent_io)
    pid = spawn(*cmd, opts)
    wait_thr = Process.detach(pid)
    child_io.each {|io| io.close }
    result = [*parent_io, wait_thr]
    if defined? yield
      begin
        return yield(*result)
      ensure
        parent_io.each{|io| io.close unless io.closed?}
        wait_thr.join
      end
    end
    result
  end
end
