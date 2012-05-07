require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

describe 'Fig' do
  describe 'usage errors' do
    before(:each) do
      cleanup_test_environment
      setup_test_environment
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

    it %q<prints error when a package descriptor consists solely of a version> do
      (out, err, exitstatus) = fig('/version', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ /No package name specified in descriptor/
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a config> do
      (out, err, exitstatus) = fig(':config', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ /No package name specified in descriptor/
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a package> do
      (out, err, exitstatus) = fig('package', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ /No version specified in descriptor/
      out.should == ''
    end

    it %q<prints error when a descriptor contains a config and --config is specified> do
      (out, err, exitstatus) = fig('package/version:default --config nondefault', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ /Cannot specify both --config and a config in the descriptor/
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a command> do
      (out, err, exitstatus) = fig('extra bits -- echo foo', nil, :no_raise_on_error)
      exitstatus.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when multiple --list-* options are given> do
      (out, err, exitstatus) =
        fig('--list-remote --list-variables', nil, :no_raise_on_error)
      exitstatus.should == 1
      out.should == ''

      %w<
        --list-configs
        --list-dependencies
        --list-local
        --list-remote
        --list-variables
      >.each do
        |option|
        err.should =~ / #{option} /x
      end
    end

    describe %q<prints error when unknown package is referenced> do
      it %q<without --update> do
        (out, err, exitstatus) =
          fig('no-such-package/version --get PATH', nil, :no_raise_on_error)
        exitstatus.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update> do
        (out, err, exitstatus) =
          fig('no-such-package/version --update --get PATH', nil, :no_raise_on_error)
        exitstatus.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update-if-missing> do
        (out, err, exitstatus) =
          fig('no-such-package/version --update-if-missing --get PATH', nil, :no_raise_on_error)
        exitstatus.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end
    end

    describe %q<prints error when referring to non-existent configuration> do
      it %q<from the command-line as the base package> do
        fig('--publish foo/1.2.3 --set FOO=BAR')
        (out, err, exitstatus) =
          fig('foo/1.2.3:non-existent-config --get FOO', nil, :no_raise_on_error)
        exitstatus.should_not == 0
        err.should =~ %r< non-existent-config >x
        out.should == ''
      end

      it %q<from the command-line as an included package> do
        fig('--publish foo/1.2.3 --set FOO=BAR')
        (out, err, exitstatus) =
          fig('--include foo/1.2.3:non-existent-config --get FOO', nil, :no_raise_on_error)
        exitstatus.should_not == 0
        err.should =~ %r< foo/1\.2\.3:non-existent-config >x
        out.should == ''
      end
    end

    it %q<refuses to publish a package named "_meta"> do
      (out, err, exitstatus) =
        fig('--publish _meta/version --set FOO=BAR', nil, :no_raise_on_error)
      exitstatus.should_not == 0
      err.should =~ %r< cannot .* _meta >x
      out.should == ''
    end
  end
end
