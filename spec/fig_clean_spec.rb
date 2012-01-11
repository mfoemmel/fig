require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

setup_repository

describe 'Fig' do
  describe '--clean' do
    it 'cleans a named package from the FIG_HOME' do
      cleanup_home_and_remote
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      fig('--publish foo/1.2.3', input)[2].should == 0
      fig('--clean foo/1.2.3')[2].should == 0
      fail unless not File.directory? FIG_HOME + '/repos/foo/1.2.3'
    end

    it 'cleans a named package from the FIG_HOME and does not clean packages differing only by version' do
      cleanup_home_and_remote
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      fig('--publish foo/1.2.3', input)[2].should == 0
      fig('--publish foo/4.5.6', input)[2].should == 0
      fig('--clean foo/1.2.3')[2].should == 0
      fail unless File.directory? FIG_HOME + '/repos/foo/4.5.6'
    end

    it 'should complain if you clean without a package descriptor' do
      cleanup_home_and_remote
      out, err, exit_code = fig('--clean', nil, :no_raise_on_error)
      out.should_not be_empty
      exit_code.should_not == 0
    end
  end
end
