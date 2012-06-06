require 'fileutils'

require 'fig/user_input_error'

module Fig; end

class Fig::UpdateLock
  def initialize(lock_directory, response)
    set_up_lock(lock_directory, response)

    return
  end

  def close()
    @lock.close

    return
  end

  private

  def set_up_lock(lock_directory, response)
    FileUtils.mkdir_p(lock_directory)

    # Tried using the directory itself as the lock, but Windows is
    # non-cooperative.
    lock_file = lock_directory + '/lock'

    # Use this instead of creating the file via File.open(lock_file, 'w') in
    # order to avoid Windows file locking issues as much as possible.
    FileUtils.touch(lock_file)

    @lock = File.new(lock_file)

    # *sigh* Ruby 1.8 doesn't support close_on_exec(), but we'll still use it
    # if we can as a better attempt at safety.
    if @lock.respond_to? :close_on_exec=
      @lock.close_on_exec = true
    end

    if response == :wait
      @lock.flock(File::LOCK_EX)
    else
      if ! @lock.flock(File::LOCK_EX | File::LOCK_NB)
        raise_lock_usage_error(lock_directory)
      end
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
