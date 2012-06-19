require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/command/option_error'
require 'fig/command/options'

def new_options(argv)
  options = Fig::Command::Options.new()
  options.process_command_line(argv)

  return options
end

def check_environment_variable_option(option_name)
  it 'complains if there is no variable name' do
    expect_invalid_value_error(option_name, '=whatever')
  end

  it 'accepts a simple variable value' do
    new_options(["--#{option_name}", 'variable=value'])
    # no exception
  end
end

describe 'Command::Options' do
  def expect_invalid_value_error(option_name, value)
    expect { new_options(["--#{option_name}", value]) }.to raise_error(
      Fig::Command::OptionError,
      %r<\AInvalid value for --#{option_name}: "#{Regexp.quote(value)}"[.]>
    )
  end

  describe %q<complains if a value isn't given to> do
    [
      %w< get >,                          # Queries
      %w< set append include override >,  # Environment
      %w< archive resource >,             # Package contents
      %w< file config log-level figrc >   # Configuration
    ].flatten.each do
      |option_name|

      describe "--#{option_name}" do
        it 'when it is the last option on the command-line' do
          expect { new_options(["--#{option_name}"]) }.to raise_error(
            Fig::Command::OptionError,
            "Please provide a value for --#{option_name}."
          )
        end

        describe 'when it is followed by' do
          # One long option example and one short option example.
          %w< --version -c >.each do
            |following_option|

            it following_option do
              expect {
                new_options( ["--#{option_name}", following_option])
              }.to raise_error(
                Fig::Command::OptionError,
                "Please provide a value for --#{option_name}."
              )
            end
          end
        end
      end
    end
  end

  describe '--file' do
    {
      'a'   => 'a single character',
      'x-'  => 'a name without a hyphen at the front',
      '-'   => 'the stdin indicator'
    }.each do
      |option_value, description|

      it %Q<allows #{description} ("#{option_value}") as a value> do
        options = new_options(['--file', option_value])
        options.package_definition_file.should == option_value
      end
    end
  end

  describe '--set' do
    check_environment_variable_option('set')

    it 'allows the absence of an equals sign' do
      new_options(%w< --set whatever >)
      # no exception
    end

    it 'allows an empty value' do
      new_options(%w< --set whatever= >)
      # no exception
    end

    it 'complains about a variable value containing a space character' do
      expect_invalid_value_error('set', 'variable= stuff')
    end
  end

  describe '--append' do
    check_environment_variable_option('append')

    it 'complains if there is no variable value' do
      expect_invalid_value_error('append', 'whatever=')
    end

    %w[ ; : " < > | ].each do
      |character|

      it %Q<complains about a variable value containing "#{character}"> do
        expect_invalid_value_error('append', "variable=#{character}")
      end
    end

    it 'complains about a variable value containing a space character' do
      expect_invalid_value_error('append', 'variable= stuff')
    end
  end
end
