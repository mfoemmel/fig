require 'fileutils'

require 'fig/user_input_error'

module Fig; end

class Fig::UpdateLock
  def initialize(lock_directory, response)
    set_up_lock(lock_directory, response)

    return
  end

  def close()
    begin
      @lock.close
    rescue IOError => error
      # Don't care if it's already closed.
    end

    return
  end

  private

  def set_up_lock(lock_directory, response)
    set_up_lock_file(lock_directory)

    should_warn = response ? false : true
    response ||= :wait

    if response == :wait
      if should_warn
        if ! @lock.flock(File::LOCK_EX | File::LOCK_NB)
          # Purposely ignoring standard logging setup so that this cannot be
          # turned off by "--log-level error".
          $stderr.puts(
            %Q<It looks like another instance of Fig is attempting to update #{lock_directory}. Will wait until it is done. (To suppress this warning in the future, explicitly specify "--update-lock-response wait".)>
          )

          @lock.flock(File::LOCK_EX)
        end
      else
        @lock.flock(File::LOCK_EX)
      end
    else
      if ! @lock.flock(File::LOCK_EX | File::LOCK_NB)
        raise_lock_usage_error(lock_directory)
      end
    end

    return
  end

  def set_up_lock_file(lock_directory)
    FileUtils.mkdir_p(lock_directory)

    # Tried using the directory itself as the lock, but Windows is
    # non-cooperative.
    lock_file = lock_directory + '/lock'

    # Yes, there's a race condition here, but with the way Windows file locking
    # works, it's better than a boot to the head.
    if ! File.exists? lock_file
      created_file = File.new(lock_file, 'w')
      created_file.close
    end

    @lock = File.new(lock_file)

    # *sigh* Ruby 1.8 doesn't support close_on_exec(), but we'll still use it
    # if we can as a better attempt at safety.
    if @lock.respond_to? :close_on_exec=
      @lock.close_on_exec = true
    end

    return
  end

  def raise_lock_usage_error(lock_directory)
    raise Fig::UserInputError.new(<<-END_MESSAGE)
Cannot update while another instance of Fig is updating #{lock_directory}.

You can tell Fig to wait for update with

    fig --update --update-lock-response wait ...

or you can throw caution to the wind with

    fig --update --update-lock-response ignore ...
    END_MESSAGE
  end
end
