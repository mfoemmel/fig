# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'cgi'

# I do not understand the scoping rules for RSpec at all.  Why does this need
# to be here and check_grammar_version() can be where it should be?
def test_asset_with_url_with_symbol(asset_type, symbol, quote, version)
  file_name     = "with#{symbol}symbol"
  escaped_file  = CGI.escape file_name
  quoted_url    =
    "#{quote}file://#{USER_HOME}/#{escaped_file}#{quote}"

  it %Q<«#{quoted_url}» (URL contains a «#{symbol}»)> do
    write_file "#{USER_HOME}/#{file_name}", ''

    fig(
      [
        %w< --publish foo/1.2.3 --set x=y >,
        "--#{asset_type}",
        quoted_url
      ],
      :current_directory => USER_HOME
    )

    check_grammar_version(version)
  end

  return
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
      pending 'not implemented yet' do
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

    describe %q<uses the correct grammar version in the published package definition> do
      def check_grammar_version(version)
        out, err = fig(%w< foo/1.2.3 --dump-package-definition-text >)

        out.should =~ /\b grammar [ ] v #{version} \b/x
        err.should == ''

        return
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

      %w< archive resource >.each do
        |asset_type|

        describe "for --#{asset_type}" do
          ['', %q<'>, %q<">].each do
            |quote|

            begin
              value = "#{quote}nothing-special#{quote}"

              it %Q<«#{value}»> do
                write_file "#{USER_HOME}/nothing-special", ''

                fig(
                  [%w< --publish foo/1.2.3 --set x=y >, "--#{asset_type}", value],
                  :current_directory => USER_HOME
                )

                check_grammar_version(0)
              end
            end

            test_asset_with_url_with_symbol(asset_type, '#', quote, 1)
          end

          %w< * ? [ ] { } >.each do
            |symbol|

            test_asset_with_url_with_symbol(asset_type, symbol, %q<'>, 1)

            ['', %q<">].each do
              |quote|

              test_asset_with_url_with_symbol(asset_type, symbol, quote, 0)
            end
          end
        end
      end
    end
  end
end
