require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe '--list-package-definition-text' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<dumps the contents of a published package> do
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      fig('--publish foo/1.2.3', input)

      (out, err, exit_status) =
        fig('foo/1.2.3 --list-package-definition-text')

      # Content from the input.
      out.should =~ /set FOO=BAR/

      # Content that is added by publishing.
      out.should =~ /publishing information for/i

      err.should == ''
    end

    it %q<dumps the contents an unpublished package> do
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      (out, err, exit_status) =
        fig('--list-package-definition-text', input)

      out.should == input.strip
      err.should == ''
    end

    it %q<fails if there is no text> do
      (out, err, exit_status) =
        fig('--list-package-definition-text', :no_raise_on_error => true)
      err.should =~ /no text/
      out.should == ''
      exit_status.should_not == 0
    end
  end
end
