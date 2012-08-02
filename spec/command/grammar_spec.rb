# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'cgi'

require 'fig/operating_system'

# I do not understand the scoping rules for RSpec at all.  Why do these need
# to be here and check_grammar_version() can be where they should be?

# Block is supposed to publish the package given a URL.
def test_asset_with_url_with_symbol(asset_type, symbol, quote, version)
  file_name     = "with#{symbol}symbol"
  escaped_file  = CGI.escape file_name
  quoted_url    =
    "#{quote}file://#{USER_HOME}/#{escaped_file}#{quote}"

  it %Q<with URL «#{quoted_url}» (contains a «#{symbol}»)> do
    write_file "#{USER_HOME}/#{file_name}", ''

    yield quoted_url

    check_grammar_version(version)

    out, err = fig(%w< foo/1.2.3 --dump-package-definition-text >)

    # Test that the statement gets rewritten without the URL.
    #
    # Assumes that all grammar versions don't put non-whitespace before the
    # asset statement.
    out.should =~ /
      ^ \s*
      #{asset_type}
      \s+
      ['"]? # Don't worry about what the grammar does with quoting.
      #{Regexp.escape file_name}
      \b
    /x
  end

  return
end

def test_command_line_asset_with_url_with_symbol(
  asset_type, symbol, quote, version
)
  test_asset_with_url_with_symbol(asset_type, symbol, quote, version) do
    |quoted_url|

    fig(
      [ %w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", quoted_url ],
      :current_directory => USER_HOME
    )
  end

  return
end

def test_asset_with_file_with_symbol(
  asset_type, symbol, quote, version
)
  file_name   = "with#{symbol}symbol"
  quoted_name = "#{quote}#{file_name}#{quote}"

  it %Q<with file «#{quoted_name}»> do
    write_file "#{USER_HOME}/#{file_name}", ''

    yield quoted_name

    check_grammar_version(version)
  end

  return
end

def test_command_line_asset_with_file_with_symbol(
  asset_type, symbol, quote, version
)
  test_asset_with_file_with_symbol(asset_type, symbol, quote, version) do
    |quoted_name|

    fig(
      [ %w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", quoted_name ],
      :current_directory => USER_HOME
    )
  end

  return
end

def full_glob_characters() return %w< * ? [ ] { } >; end
def testable_glob_characters()
  return full_glob_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end

def full_special_characters() return full_glob_characters + %w< # >; end
def testable_special_characters()
  return full_special_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end

describe 'Fig' do
  describe 'grammar statement' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    %w< 0 1 >.each do
      |version|

      it %Q<for v#{version} is accepted> do
        input = <<-"END"
          # A comment
          grammar v#{version}
          config default
            command "echo foo"
          end
        END

        out, err = fig(%w<--run-command-statement>, input)
        err.should == ''
        out.should == 'foo'
      end
    end

    it %q<is not accepted if it isn't the first statement> do
      pending 'user-friendly warning message not implemented yet' do
        input = <<-END
          config default
          end
          grammar v1
        END

        out, err, exit_code = fig([], input, :no_raise_on_error => true)
        err.should =~ /grammar statement wasn't first statement/i
        out.should == ''
        exit_code.should_not == 0
      end
    end

    it %q<is not accepted for future version> do
      input = <<-END
        grammar v31415269
        config default
        end
      END

      out, err, exit_code = fig([], input, :no_raise_on_error => true)
      err.should =~ /don't know how to parse grammar version/i
      out.should == ''
      exit_code.should_not == 0
    end
  end

  describe %q<uses the correct grammar version in the package definition created for publishing> do
    def check_grammar_version(version)
      out, err = fig(%w< foo/1.2.3 --dump-package-definition-text >)

      out.should =~ /\b grammar [ ] v #{version} \b/x
      err.should == ''

      return
    end

    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it 'from unversioned file input' do
      input = <<-END
        config default
        end
      END
      fig(%w< --publish foo/1.2.3 >, input)

      check_grammar_version(0)
    end

    it 'from v1 grammar file input' do
      input = <<-END
        grammar v1
        config default
        end
      END
      fig(%w< --publish foo/1.2.3 >, input)

      check_grammar_version(1)
    end

    %w< set append >.each do
      |option|

      it "for simple --#{option}" do
        fig [%w< --publish foo/1.2.3>, "--#{option}", 'VARIABLE=VALUE']

        check_grammar_version(0)
      end
    end

    shared_examples_for 'asset option' do
      |asset_type|

      ['', %q<'>, %q<">].each do
        |quote|

        begin
          value = "#{quote}nothing-special#{quote}"

          it %Q<with file «#{value}»> do
            write_file "#{USER_HOME}/nothing-special", ''

            fig(
              [%w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", value],
              :current_directory => USER_HOME
            )

            check_grammar_version(0)
          end
        end

        test_command_line_asset_with_url_with_symbol(asset_type, '#', quote, 1)
      end

      testable_glob_characters.each do
        |symbol|

        test_command_line_asset_with_url_with_symbol(
          asset_type, symbol, %q<'>, 1
        )

        ['', %q<">].each do
          |quote|

          test_command_line_asset_with_url_with_symbol(
            asset_type, symbol, quote, 0
          )
        end
      end
    end

    describe 'for --archive' do
      it_behaves_like 'asset option', 'archive'

      ['', %q<'>, %q<">].each do
        |quote|

        testable_special_characters.each do
          |symbol|

          test_command_line_asset_with_file_with_symbol(
            'archive', symbol, quote, 1
          )
        end
      end
    end

    describe 'for --resource' do
      it_behaves_like 'asset option', 'resource'

      ['', %q<'>, %q<">].each do
        |quote|

        testable_special_characters.each do
          |symbol|

          test_command_line_asset_with_file_with_symbol(
            'resource', symbol, quote, 0
          )
        end
      end
    end
  end
end
