# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

require 'cgi'

require 'fig/operating_system'

# I do not understand the scoping rules for RSpec at all.

# Block is supposed to publish the package given a URL.
def test_published_asset_with_url_with_symbol(
  asset_type, symbol, quote, version
)
  file_name     = "with#{symbol}symbol"
  escaped_file  = CGI.escape file_name
  quoted_url    =
    "#{quote}file://#{USER_HOME}/#{escaped_file}#{quote}"

  it %Q<with URL «#{quoted_url}» (contains a «#{symbol}»)> do
    write_file "#{USER_HOME}/#{file_name}", ''

    yield quoted_url

    check_published_grammar_version(version)

    out, err =
      fig(%w< foo/1.2.3 --dump-package-definition-text >, :fork => false)

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

def test_published_command_line_asset_with_url_with_symbol(
  asset_type, symbol, quote, version
)
  test_published_asset_with_url_with_symbol(
    asset_type, symbol, quote, version
  ) do
    |quoted_url|

    fig(
      [ %w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", quoted_url ],
      :current_directory => USER_HOME,
      :fork => false
    )
  end

  return
end

def test_published_file_asset_with_url_with_symbol(
  asset_type, symbol, quote, version
)
  test_published_asset_with_url_with_symbol(
    asset_type, symbol, quote, version
  ) do
    |quoted_url|

    input = <<-"END"
      grammar v1

      #{asset_type} #{quoted_url}

      config default
      end
    END
    fig(
      %w< --publish foo/1.2.3 >,
      input,
      :current_directory => USER_HOME,
      :fork => false
    )
  end

  return
end

def test_published_asset_with_file_with_symbol(
  asset_type, symbol, quote, version
)
  file_name   = "with#{symbol}symbol"
  quoted_name = "#{quote}#{file_name}#{quote}"

  it %Q<with file «#{quoted_name}»> do
    write_file "#{USER_HOME}/#{file_name}", ''

    yield quoted_name

    check_published_grammar_version(version)
  end

  return
end

def test_published_command_line_asset_with_file_with_symbol(
  asset_type, symbol, quote, version
)
  test_published_asset_with_file_with_symbol(
    asset_type, symbol, quote, version
  ) do
    |quoted_name|

    fig(
      [ %w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", quoted_name ],
      :current_directory => USER_HOME,
      :fork => false
    )
  end

  return
end

def test_published_file_asset_with_file_with_symbol(
  asset_type, symbol, quote, version
)
  test_published_asset_with_file_with_symbol(
    asset_type, symbol, quote, version
  ) do
    |quoted_url|

    input = <<-"END"
      grammar v1

      #{asset_type} #{quoted_url}

      config default
      end
    END
    fig(
      %w< --publish foo/1.2.3 >,
      input,
      :current_directory => USER_HOME,
      :fork => false
    )
  end

  return
end

def full_glob_characters() return %w< * ? [ ] { } >; end
def testable_glob_characters()
  return full_glob_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end

def v1_special_characters() return full_glob_characters + %w[ # ]; end
def v1_non_special_characters() return %w[ < > | ]; end
def v0_special_characters()
  return v1_special_characters + v1_non_special_characters
end
def testable_v1_special_characters()
  return v1_special_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end
def testable_v1_non_special_characters()
  return v1_non_special_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end
def testable_v0_special_characters()
  return v0_special_characters() -
    Fig::OperatingSystem.file_name_illegal_characters
end

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
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
              :current_directory => USER_HOME,
              :fork => false
            )

            check_published_grammar_version(0)
          end
        end

        test_published_command_line_asset_with_url_with_symbol(
          asset_type, '#', quote, 1
        )
      end

      testable_glob_characters.each do
        |symbol|

        test_published_command_line_asset_with_url_with_symbol(
          asset_type, symbol, %q<'>, 1
        )

        ['', %q<">].each do
          |quote|

          test_published_command_line_asset_with_url_with_symbol(
            asset_type, symbol, quote, 0
          )
        end
      end
    end

    describe 'for --archive' do
      ['', %q<'>, %q<">].each do
        |quote|

        testable_v1_special_characters.each do
          |symbol|

          test_published_command_line_asset_with_file_with_symbol(
            'archive', symbol, quote, 1
          )
        end

        testable_v1_non_special_characters.each do
          |symbol|

          test_published_command_line_asset_with_file_with_symbol(
            'archive', symbol, quote, 1
          )
        end
      end

      it_behaves_like 'asset option', 'archive'
    end

    describe 'for --resource' do
      ['', %q<'>, %q<">].each do
        |quote|

        testable_v0_special_characters.each do
          |symbol|

          test_published_command_line_asset_with_file_with_symbol(
            'resource', symbol, quote, 0
          )
        end
      end

      it_behaves_like 'asset option', 'resource'
    end

    shared_examples_for 'asset statement' do
      |asset_type|

      ['', %q<'>, %q<">].each do
        |quote|

        begin
          value = "#{quote}nothing-special#{quote}"

          it %Q<with file «#{value}»> do
            write_file "#{USER_HOME}/nothing-special", ''

            input = <<-"END"
              grammar v1

              #{asset_type} #{value}

              config default
              end
            END
            fig(
              %w< --publish foo/1.2.3 >,
              input,
              :current_directory => USER_HOME,
              :fork => false
            )

            check_published_grammar_version(0)
          end
        end

        test_published_file_asset_with_url_with_symbol(
          asset_type, '#', quote, 1
        )
      end

      testable_glob_characters.each do
        |symbol|

        test_published_file_asset_with_url_with_symbol(
          asset_type, symbol, %q<'>, 1
        )

        ['', %q<">].each do
          |quote|

          test_published_file_asset_with_url_with_symbol(
            asset_type, symbol, quote, 0
          )
        end
      end
    end

    describe 'for archive statement' do
      ['', %q<'>, %q<">].each do
        |quote|

        (testable_v1_special_characters - %w<#>).each do
          |symbol|

          test_published_file_asset_with_file_with_symbol(
            'archive', symbol, quote, 1
          )
        end

        testable_v1_non_special_characters.each do
          |symbol|

          test_published_file_asset_with_file_with_symbol(
            'archive', symbol, quote, 1
          )
        end
      end

      [%q<'>, %q<">].each do
        |quote|

        test_published_file_asset_with_file_with_symbol(
          'archive', '#', quote, 1
        )
      end

      it_behaves_like 'asset statement', 'archive'
    end

    describe 'for resource statement' do
      ['', %q<'>, %q<">].each do
        |quote|

        (testable_v0_special_characters - %w<#>).each do
          |symbol|

          test_published_file_asset_with_file_with_symbol(
            'resource', symbol, quote, 0
          )
        end
      end

      [%q<'>, %q<">].each do
        |quote|

        test_published_file_asset_with_file_with_symbol(
          'resource', '#', quote, 0
        )
      end

      it_behaves_like 'asset statement', 'resource'
    end
  end

  describe %q<uses the correct grammar version in the package definition after parsing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    %w< archive resource >.each do
      |asset_type|

      describe "#{asset_type} statement" do
        [%q<'>, %q<">].each do
          |quote|

          value = "#{quote}contains#octothorpe#{quote}"
          it %Q<with input containing «#{value}»> do
            input = <<-"END"
              grammar v1
              #{asset_type} #{value}
            END

            out, err = fig(
              ['--dump-package-definition-parsed'],
              input,
              :current_directory => USER_HOME,
              :fork => false
            )
            out.should =~ /\b grammar [ ] v1 \b/x
            err.should == ''
          end
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
