# coding: utf-8

module Fig; end
class Fig::Command; end

# One of the main activities Fig should do as part of the current run.
#
# This exists because the code used to have complicated logic about whether a
# package.fig should be read, whether the Package object should be loaded,
# should a config be applied, when should some activity happen, etc.  Now, we
# let the Action object say what it wants in terms of setup and then tell it to
# do whatever it needs to.
module Fig::Command::Action
  EXIT_SUCCESS = 0
  EXIT_FAILURE = 1

  attr_writer :execution_context

  def primary_option()
    return options()[0]
  end

  def options()
    raise NotImplementedError
  end

  # Is this a special Action that should just be run on its own without looking
  # at other Actions?  Note that anything that returns true won't get an
  # execution context.
  def execute_immediately_after_command_line_parse?
    return false
  end

  def descriptor_requirement()
    raise NotImplementedError
  end

  def allow_both_descriptor_and_file?()
    return false
  end

  # Does the action care about command-line options that affect package
  # contents, i.e. --resource/--archive?
  def cares_about_asset_options?()
    return false
  end

  def modifies_repository?()
    raise NotImplementedError
  end

  def prepare_repository(repository)
    return # Nothing by default.
  end

  def load_base_package?()
    raise NotImplementedError
  end

  def base_package_can_come_from_descriptor?()
    return true
  end

  # true, false, or nil if don't care.
  def register_base_package?()
    raise NotImplementedError
  end

  # true, false, or nil if don't care.
  def apply_config?()
    raise NotImplementedError
  end

  # true, false, or nil if don't care.
  def apply_base_config?()
    raise NotImplementedError
  end

  def remote_operation_necessary?()
    return false
  end

  def retrieves_should_happen?()
    return false
  end

  # Is this --list-dependencies?
  def list_dependencies?()
    return false
  end

  # Is this --list-variables?
  def list_variables?()
    return false
  end

  # Is this a publish action?
  def publish?()
    return false
  end

  # Answers whether we should reset the environment to nothing, sort of like
  # the standardized environment that cron(1) creates.  At present, we're only
  # setting this when we're listing variables.  One could imagine allowing this
  # to be set by a command-line option in general; if we do this, the
  # RuntimeEnvironment class will need to be changed to support deletion of
  # values from ENV.
  def reset_environment?()
    return false
  end

  # Slurp data out of command-line options.
  def configure(options)
    # Do nothing by default.
    return
  end

  def execute()
    raise NotImplementedError
  end
end
