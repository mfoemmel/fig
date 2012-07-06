require 'optparse'

require 'fig/command/option_error'

module Fig; end
class Fig::Command; end
class Fig::Command::Options; end

# Command-line processing.
class Fig::Command::Options::Parser
  # This class knows way too much about how OptionParser works.

  SHORT_USAGE = <<-'END_SHORT_USAGE'
Short usage summary (use --help-long for everything):

Running under Fig:
  fig [...] [DESCRIPTOR] [-- COMMAND]
  fig [...] [DESCRIPTOR] --command-extra-args VALUES
  fig [...] [DESCRIPTOR] --run-command-statement

Querying:
  fig {-g | --get} VARIABLE                                  [DESCRIPTOR] [...]
  fig --list-dependencies [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig --list-variables [--list-tree] [--list-all-configs]    [DESCRIPTOR] [...]

Publishing packages:
  fig {--publish | --publish-local} DESCRIPTOR
      [--resource PATH]      [--archive  PATH]
      [--include DESCRIPTOR] [--override DESCRIPTOR]
      [...]

Standard options (represented as "[...]" above):
      [--update | --update-if-missing]
      [--set    VARIABLE=VALUE]
      [--append VARIABLE=VALUE]
      [--file PATH] [--no-file]

(--options for full option list; --help-long for everything)
  END_SHORT_USAGE

  FULL_USAGE = <<-'END_FULL_USAGE'
Running under Fig:

  fig [...] [DESCRIPTOR] [-- COMMAND]
  fig [...] [DESCRIPTOR] --command-extra-args VALUES
  fig [...] [DESCRIPTOR] --run-command-statement

Querying:

  fig {-g | --get} VARIABLE                                  [DESCRIPTOR] [...]
  fig --list-dependencies [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig --list-variables    [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig --list-configs                                         [DESCRIPTOR] [...]
  fig --dump-package-definition-text                         [DESCRIPTOR] [...]
  fig --dump-package-definition-parsed                       [DESCRIPTOR] [...]
  fig {--list-local | --list-remote}                                      [...]

Publishing packages:

  fig {--publish | --publish-local} DESCRIPTOR
      [--resource       PATH]
      [--archive        PATH]
      [{-i | --include} DESCRIPTOR]
      [--override       DESCRIPTOR]
      [--force]
      [...]

Local repository maintenance:

  fig --clean DESCRIPTOR [...]

Standard options (represented as "[...]" above):

      [-u | --update | -m | --update-if-missing]
      --update-lock-response {wait | fail | ignore}

      [{-s | --set}    VARIABLE=VALUE]
      [{-p | --append} VARIABLE=VALUE]

      [--file PATH] [--no-file]
      [{-c | --config} CONFIG]

      [-l | --login]

      [--log-level LEVEL] [--log-config PATH]
      [--figrc PATH]      [--no-figrc]

      [--suppress-warning-include-statement-missing-version]

Information:

  fig --help
  fig --help-long
  fig --options
  fig {-v | --version}


A DESCRIPTOR looks like <package name>[/<version>][:<config>] e.g. "foo",
"foo/1.2.3", and "foo/1.2.3:default". Whether ":<config>" and "/<version>" are
required or allowed is dependent upon what your are doing.

Environment variables:

  FIG_REMOTE_URL location of remote repository, required for remote operations
  FIG_HOME       path to local repository, defaults to $HOME/.fighome
  END_FULL_USAGE

  def initialize()
    @switches             = {}
    @argument_description = {}
    @parser               = OptionParser.new

    @parser.banner = "#{FULL_USAGE}\nAll options:\n\n"
  end

  def add_argument_description(options, description)
    if options.is_a? Array
      options.each do
        |option|

        @argument_description[option] = description
      end
    else
      @argument_description[options] = description
    end

    return
  end

  def on_head(*arguments, &block)
    switch_array = make_switch_array(arguments, block)

    return if not switch_array

    @parser.top.prepend(*switch_array)

    return
  end

  def on(*arguments, &block)
    switch_array = make_switch_array(arguments, block)

    return if not switch_array

    @parser.top.append(*switch_array)

    return
  end

  def on_tail(*arguments, &block)
    switch_array = make_switch_array(arguments, block)

    return if not switch_array

    @parser.base.append(*switch_array)

    return
  end

  def short_help()
    return SHORT_USAGE
  end

  def full_help()
    return @parser.help
  end

  def options_message()
    return @parser.summarize('')
  end

  def parse!(argv)
    begin
      @parser.parse!(argv)
    rescue OptionParser::InvalidArgument => error
      raise_invalid_argument(error.args[0], error.args[1])
    rescue OptionParser::MissingArgument => error
      raise_missing_argument(error.args[0])
    rescue OptionParser::InvalidOption => error
      raise Fig::Command::OptionError.new(
        "Unknown option #{error.args[0]}.\n\n#{SHORT_USAGE}"
      )
    rescue OptionParser::ParseError => error
      raise Fig::Command::OptionError.new(error.to_s)
    end

    return
  end

  def raise_invalid_argument(option, value, description = nil)
    # *sigh* OptionParser does not raise MissingArgument for the case of an
    # option with a required value being followed by another option.  It
    # assigns the next option as the value instead.  E.g. for
    #
    #    fig --set --get FOO
    #
    # it assigns "--get" as the value of the "--set" option.
    if @switches.has_key? value
      raise_missing_argument(option)
    end

    description ||= @argument_description[option]
    if description.nil?
      description = ''
    else
      description = ' ' + description
    end

    raise Fig::Command::OptionError.new(
      %Q<Invalid value for #{option}: "#{value}".#{description}>
    )
  end

  private

  def make_switch_array(arguments, block)
    # This method is a means of interjecting ourselves between the creation of
    # a Switch object and putting it into the list of actual switches.
    #
    # From the OptionParser code, the contents of the array:
    #
    # +switch+::      OptionParser::Switch instance to be inserted.
    # +short_opts+::  List of short style options.
    # +long_opts+::   List of long style options.
    # +nolong_opts+:: List of long style options with "no-" prefix.
    #
    # Why returning this data separate from the Switch object is necessary, I
    # do not understand.

    switch_array = @parser.make_switch(arguments, block)
    switch = switch_array[0]

    options = [switch.long, switch.short].flatten

    return if options.any? {|option| @switches.has_key? option}

    options.each {|option| @switches[option] = switch}

    return switch_array
  end

  def raise_missing_argument(option)
    raise Fig::Command::OptionError.new(
      "Please provide a value for #{option}."
    )
  end
end
