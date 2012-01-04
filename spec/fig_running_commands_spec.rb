require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

require 'fig/os'

setup_repository

describe 'Fig' do
  describe 'running commands' do
    before(:all) do
      FileUtils.mkdir_p(FIG_SPEC_BASE_DIRECTORY)
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
