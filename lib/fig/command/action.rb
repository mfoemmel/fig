module Fig; end
class Fig::Command; end

module Fig::Command::Action
  # Slurp data out of command-line options.
  def configure(options)
    # Do nothing by default.
  end

  def execute(repository)
    raise NotImplementedError
  end
end
