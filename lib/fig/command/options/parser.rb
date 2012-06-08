require 'optparse'

require 'fig/command/option_error'

module Fig; end
class Fig::Command; end
class Fig::Command::Options; end

# Command-line processing.
class Fig::Command::Options::Parser
  USAGE = <<-EOF
Usage:

  fig [...] [DESCRIPTOR] [--update | --update-if-missing] [-- COMMAND]
  fig [...] [DESCRIPTOR] [--update | --update-if-missing] [--command-extra-args VALUES]

  fig {--publish | --publish-local} DESCRIPTOR
      [--resource PATH]
      [--archive  PATH]
      [--include  DESCRIPTOR]
      [--override DESCRIPTOR]
      [--force]
      [...]

  fig --clean DESCRIPTOR [...]

  fig --get VARIABLE                                         [DESCRIPTOR] [...]
  fig --list-configs                                         [DESCRIPTOR] [...]
  fig --list-dependencies [--list-tree] [--list-all-configs] [DESCRIPTOR] [...]
  fig --list-variables [--list-tree] [--list-all-configs]    [DESCRIPTOR] [...]
  fig {--list-local | --list-remote}                                      [...]

  fig {--version | --help}


A DESCRIPTOR looks like <package name>[/<version>][:<config>] e.g. "foo",
"foo/1.2.3", and "foo/1.2.3:default". Whether ":<config>" and "/<version>" are
required or allowed is dependent upon what your are doing.

Standard options (represented as "[...]" above):

      [--set    VARIABLE=VALUE]
      [--append VARIABLE=VALUE]
      [--file PATH] [--no-file]
      [--config CONFIG]
      [--login]
      [--log-level LEVEL] [--log-config PATH]
      [--figrc PATH] [--no-figrc]
      [--suppress-warning-include-statement-missing-version]

Environment variables:

  FIG_REMOTE_URL (required),
  FIG_HOME (path to local repository cache, defaults to $HOME/.fighome).
  EOF

  def initialize()
    @switches             = []
    @argument_description = {}
    @parser               = OptionParser.new

    @parser.banner = "#{USAGE}\n"
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
    switch_array = @parser.make_switch(arguments, block)
    @parser.top.prepend(*switch_array)
    @switches << switch_array[0]

    return
  end

  def on(*arguments, &block)
    switch_array = @parser.make_switch(arguments, block)
    @parser.top.append(*switch_array)
    @switches << switch_array[0]

    return
  end

  def on_tail(*arguments, &block)
    switch_array = @parser.make_switch(arguments, block)
    @parser.base.append(*switch_array)
    @switches << switch_array[0]

    return
  end

  def help()
    return @parser.help
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
        "Unknown option #{error.args[0]}.\n\n#{USAGE}"
      )
    rescue OptionParser::ParseError => error
      raise Fig::Command::OptionError.new(error.to_s)
    end

    return
  end

  def raise_invalid_argument(option, value)
    # *sigh* OptionParser does not raise MissingArgument for the case of an
    # option with a required value being followed by another option.  It
    # assigns the next option as the value instead.  E.g. for
    #
    #    fig --set --get FOO
    #
    # it assigns "--get" as the value of the "--set" option.
    switch_strings =
      (@switches.collect {|switch| [switch.short, switch.long]}).flatten
    if switch_strings.any? {|string| string == value}
      raise_missing_argument(option)
    end

    description = @argument_description[option]
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

  def raise_missing_argument(option)
    raise Fig::Command::OptionError.new(
      "Please provide a value for #{option}."
    )
  end
end
