require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Fig' do
  describe 'running commands in a package config section' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<runs a command> do
      input = <<-END
        config default
          command "echo foo"
        end
      END
      fig('--publish foo/1.2.3', input)

      (out, err, exitstatus) = fig('foo/1.2.3', nil)
      exitstatus.should == 0
      out.should == 'foo'
      err.should == ''
    end

    it %q<passes command-line arguments to the command> do
      input = <<-END
        config default
          command "echo Hi"
        end
      END
      fig('--publish foo/1.2.3', input)

      (out, err, exitstatus) =
        fig('foo/1.2.3 --command-extra-args there', nil)
      exitstatus.should == 0
      out.should == 'Hi there'
      err.should == ''
    end

    it %q<fails if command-line arguments specified but no command found> do
      input = <<-END
        config default
        end
      END
      fig('--publish foo/1.2.3', input)

      (out, err, exitstatus) =
        fig('foo/1.2.3 --command-extra-args yadda', nil, :no_raise_on_error)
      exitstatus.should_not == 0
      out.should == ''
      err.should =~ /does not contain a command/
    end

    it %q<prints a warning message when attempting to run multiple commands> do
      input = <<-END
        config default
          command "echo foo"
          command "echo bar"
        end
      END
      out, err, exit_code =
        fig('--publish foo/1.2.3.4', input, :no_raise_on_error)
      err.should =~
        %r<Found a second "command" statement within a "config" block \(line>
    end
  end
end
