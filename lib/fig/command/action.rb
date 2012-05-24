module Fig; end
class Fig::Command; end

module Fig::Command::Action
  def allow_both_descriptor_and_file?
    return false
  end

  # Slurp data out of command-line options.
  def configure(options)
    # Do nothing by default.
    return
  end

  def execute(repository)
    raise NotImplementedError
  end
end
