require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe 'grammar statement' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<for v1 is accepted> do
      input = <<-END
        # A comment
        grammar v1
        config default
          command "echo foo"
        end
      END

      (out, err, exitstatus) = fig(%w<--run-command-statement>, input)
      err.should == ''
      out.should == 'foo'
      exitstatus.should == 0
    end

    pending %q<is not accepted if it isn't the first statement> do
      input = <<-END
        config default
        end
        grammar v1
      END

      (out, err, exitstatus) = fig([], input, :no_raise_on_error => true)
      err.should =~ /grammar statement wasn't first statement/i
      out.should == ''
      exitstatus.should_not == 0
    end

    it %q<is not accepted for future version> do
      input = <<-END
        grammar v31415269
        config default
        end
      END

      (out, err, exitstatus) = fig([], input, :no_raise_on_error => true)
      err.should =~ /don't know how to parse grammar version/i
      out.should == ''
      exitstatus.should_not == 0
    end
  end
end
