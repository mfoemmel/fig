# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

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
            set variable=foo
          end
        END

        out, err = fig(%w<--get variable>, input, :fork => false)
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

        out, err, exit_code =
          fig([], input, :no_raise_on_error => true, :fork => false)
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

      out, err, exit_code =
        fig([], input, :no_raise_on_error => true, :fork => false)
      err.should =~ /don't know how to parse grammar version/i
      out.should == ''
      exit_code.should_not == 0
    end
  end

  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it 'from unversioned file input with a "default" config' do
      input = <<-END
        config default
        end
      END
      fig(%w< --publish foo/1.2.3 >, input, :fork => false)

      check_published_grammar_version(0)
    end

    %w< 1 >.each do
      |version|

      it %Q<from v#{version} grammar file input with a "default" config> do
        input = <<-END
          grammar v#{version}
          config default
          end
        END
        fig(%w< --publish foo/1.2.3 >, input, :fork => false)

        check_published_grammar_version(0)
      end
    end
  end
end

# vim: set fileencoding=utf8 :
