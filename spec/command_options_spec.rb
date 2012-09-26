# coding: utf-8

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

  it 'complains if there are unbalanced single quotes' do
    expect_invalid_value_error(option_name, %q<'>)
  end

  it 'allows a variable value containing an escaped single quote' do
    new_options( ["--#{option_name}", %q<variable=\'>] )
    # no exception
  end

  it 'complains if there are unbalanced double quotes' do
    expect_invalid_value_error(option_name, %q<">)
  end

  it 'allows a variable value containing an escaped double quote' do
    new_options( ["--#{option_name}", %q<variable=\">] )
    # no exception
  end

  it 'allows a variable value containing a space character' do
    new_options( ["--#{option_name}", 'variable= stuff'] )
    # no exception
  end

  it 'allows a variable value containing an octothorpe' do
    new_options( ["--#{option_name}", 'variable=red#green#blue'] )
    # no exception
  end
end

describe 'Command::Options' do
  def expect_invalid_value_error(option_name, value)
    expect { new_options(["--#{option_name}", value]) }.to raise_error(
      Fig::Command::OptionError,
      %r<\AInvalid value for --#{option_name}: "#{Regexp.quote(value)}">
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
  end

  describe '--append' do
    check_environment_variable_option('append')

    it 'complains if there is no variable value' do
      expect_invalid_value_error('append', 'whatever=')
    end

    %w[ ; : < > | ].each do
      |character|

      # Need to check this because they are not allowed in the v0 grammar.
      it %Q<allows a variable value containing "#{character}"> do
        new_options( ['--append', "variable=#{character}"] )
        # no exception
      end
    end
  end

  %w< archive resource >.each do
    |asset_type|

    describe "--#{asset_type}" do
      it 'complains if there is no value' do
        expect_invalid_value_error(asset_type, '')
      end

      %w[ " ' ].each do
        |character|

        it %Q<complains about a value containing unbalanced «#{character}»> do
          expect_invalid_value_error(asset_type, character)
        end

        it "accepts a value quoted by «#{character}»" do
          new_options(["--#{asset_type}", "#{character}x#{character}"])
          # no exception
        end

        it "accepts a value with an escaped «#{character}»" do
          new_options(["--#{asset_type}", "x\\#{character}x"])
          # no exception
        end
      end

      # Just to check that people don't think that "@" is a special character
      # here.
      it %Q<complains about a value containing escaped «@»> do
        expect_invalid_value_error(asset_type, '\\@')
      end
    end
  end
end

# vim: set fileencoding=utf8 :
