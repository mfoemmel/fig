require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Fig' do
  describe 'running commands' do
    before(:each) do
      cleanup_test_environment
      setup_test_environment
    end

    it %q<runs a single command> do
      input = <<-END
        config default
          command "echo foo"
        end
      END
      fig('--publish foo/1.2.3', input)
      fig('foo/1.2.3').first.should == 'foo'
    end

    it %q<prints a warning message when attempting to run multiple commands> do
      input = <<-END
        config default
          command "echo foo"
          command "echo bar"
        end
      END
      fig('--publish foo/1.2.3.4', input, :no_raise_on_error).first.should == 'Multiple command statements cannot be processed.'
    end
  end
end
