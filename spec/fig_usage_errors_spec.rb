require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

setup_repository

describe 'Fig' do
  describe 'usage errors' do
    before(:all) do
      FileUtils.mkdir_p(FIG_SPEC_BASE_DIRECTORY)
    end

    it %q<prints usage message when passed an unknown option> do
      (out, err, exitstatus) = fig('--no-such-option', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / --no-such-option /x
      err.should =~ / usage /xi
      out.should == ''
    end

    it %q<prints usage message when there's nothing to do and there's no package.fig file> do
      (out, err, exitstatus) = fig('', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / usage /xi
      out.should == ''
    end

    it %q<prints usage message when there's nothing to do and there's a package.fig file> do
      File.open "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::DEFAULT_FIG_FILE}", 'w' do
        |handle|
        handle.print <<-END
          config default
          end
        END
      end

      (out, err, exitstatus) = fig('', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / usage /xi
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a package descriptor> do
      (out, err, exitstatus) = fig('package/descriptor extra bits', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a command> do
      (out, err, exitstatus) = fig('extra bits -- echo foo', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end
  end
end
