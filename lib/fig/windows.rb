require 'erb'
require 'fileutils'

# I don't know how to set environment variables so that a sub-shell will
# be able to use them.  Therefore, I'm punting, and creating a batch script
# on the fly to run a user supplied command.

module Fig
  # Windows-specific implementation details.
  class Windows
    BATCH_SCRIPT_TEMPLATE = <<EOF
@echo off
% ENV.each do |k,v|
set <%= k %>=<%= v %>
% end

cmd /C <%= command %>
EOF


    def self.with_generated_batch_script(cmd)
      command = cmd.join(' ')
      template = ERB.new(BATCH_SCRIPT_TEMPLATE, 0, '%')
      output = template.result(binding)
      begin
        tf = File.new('C:/tmp/fig_command.bat', 'w')
        FileUtils.chmod(0755, tf.path)
        File.open(tf.path, 'w') do |fh|
          fh.puts output
        end
        tf.close
        yield tf.path
      ensure
#        tf.delete
      end
    end

    def self.shell_exec_windows(cmd)
      with_generated_batch_script(cmd) do |f|
        Kernel.exec(f)
      end
    end
  end
end
