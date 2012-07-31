require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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

    describe %q<adds the grammar version to the published package definition> do
      it 'from file input' do
        input = <<-END
          config default
          end
        END
        fig(%w< --publish foo/1.2.3 >, input)

        out, err = fig(%w< foo/1.2.3 --dump-package-definition-text >)

        out.should =~ /\b grammar [ ] v0 \b/x
      end

      it 'from command-line input' do
        fig(%w< --publish foo/1.2.3 --set VARIABLE=VALUE >)

        out, err = fig(%w< foo/1.2.3 --dump-package-definition-text >)
        out.should =~ /\b grammar [ ] v0 \b/x
      end
    end
  end
end
