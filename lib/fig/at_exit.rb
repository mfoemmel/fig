# coding: utf-8

module Fig; end

# This exists because standard Kernel#at_exit blocks don't get run before
# Kernel#exec.
class Fig::AtExit
  def self.add(&block)
    EXIT_PROCS << block

    return
  end

  def self.execute()
    EXIT_PROCS.each do
      |proc|

      begin
        proc.call()
      rescue StandardError => exception
        $stderr.puts(
          [
            %q<Got exception from "at exit" processing.>,
            exception.message,
            exception.backtrace
          ].flatten.join("\n")
        )
      end
    end

    return
  end

  private

  EXIT_PROCS = []

  at_exit { Fig::AtExit.execute() }
end
