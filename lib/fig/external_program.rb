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
end
