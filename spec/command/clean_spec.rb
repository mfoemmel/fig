require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe '--clean' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
      cleanup_home_and_remote
    end

    it 'cleans a named package from the FIG_HOME' do
      fig(%w<--publish foo/1.2.3 --set FOO=BAR>)[2].should == 0
      fig(%w<--clean foo/1.2.3>)[2].should == 0
      fail unless not File.directory? FIG_HOME + '/packages/foo/1.2.3'
    end

    it 'cleans a named package from the FIG_HOME and does not clean packages differing only by version' do
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      fig(%w<--publish foo/1.2.3>, input)[2].should == 0
      fig(%w<--publish foo/4.5.6>, input)[2].should == 0
      fig(%w<--clean foo/1.2.3>)[2].should == 0
      fail unless File.directory? FIG_HOME + '/packages/foo/4.5.6'
    end

    it 'should complain if you clean without a package descriptor' do
      out, err, exit_code = fig(%w<--clean>, :no_raise_on_error => true)
      err.should =~ /need to specify a descriptor/i
      exit_code.should_not == 0
    end

    it %q<should complain if local repository isn't in the expected format version> do
      fig(%w<--publish foo/1.2.3 --set FOO=BAR>)[2].should == 0

      set_local_repository_format_to_future_version()
      out, err, exit_code =
        fig(%w<--clean foo/1.2.3>, :no_raise_on_error => true)
      err.should =~
        /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
      exit_code.should_not == 0
    end

    %w< --update --update-if-missing >.each do
      |option|

      it %Q<should complain if #{option} is specified> do
        fig(%w<--publish foo/1.2.3 --set FOO=BAR>)[2].should == 0

        out, err, exit_code =
          fig([option, '--clean', 'foo/1.2.3'], :no_raise_on_error => true)
        err.should =~
          /because they disagree on whether the base package should be loaded/
        exit_code.should_not == 0
      end
    end
  end
end
