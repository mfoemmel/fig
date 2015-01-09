# coding: utf-8

require 'stringio'

require 'fig/user_input_error'

module Fig; end

class Fig::ExternalProgram
  def self.popen(*cmd)
    exit_code = nil

    options = {}
    stdin_read, stdin_write = IO.pipe Encoding::UTF_8, Encoding::UTF_8
    options[:in] = stdin_read
    stdin_write.sync = true

    stdout_read, stdout_write = IO.pipe Encoding::UTF_8, Encoding::UTF_8
    options[:out] = stdout_write

    stderr_read, stderr_write = IO.pipe Encoding::UTF_8, Encoding::UTF_8
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
            # #readpartial() is busted in that it is returning a byte array in
            # a String with a bogus Encoding, even though the bytes may not be
            # valid in the Encoding.
            input_to_output[handle] << handle.readpartial(4096)
          rescue EOFError
            input_to_output.delete handle
          end
        end
      end
    end

    output_string = string_io_byte_array_to_utf8_string output
    errors_string = string_io_byte_array_to_utf8_string errors

    return output_string, errors_string, result
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

  # There appears to be no way to convert from a byte array to a UTF-8 string
  # cleanly, with a report of where things are wrong.
  def self.string_io_byte_array_to_utf8_string(string_io)
    string = string_io.string
    string.force_encoding(Encoding::UTF_8)
    if ! string.valid_encoding?
      # Seriously lame, uninformative error message, but, hopefully, this is
      # rare and I don't think I can spend the time to gather the information
      # to make this better right now.
      raise UserInputError.new 'Got invalid UTF-8 input.'
    end

    return string
  end
end
