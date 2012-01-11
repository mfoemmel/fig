require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

setup_repository

def set_up_local_and_remote_repository
  cleanup_home_and_remote

  input = <<-END_INPUT
    config default
      set FOO=BAR
    end
    config nondefault
      set FOO=BAZ
    end
  END_INPUT
  fig('--publish prerequisite/1.2.3', input)

  input = <<-END_INPUT
    config default
      include prerequisite/1.2.3
      set FOO=BAR
    end
    config nondefault
      include prerequisite/1.2.3
      set FOO=BAZ
    end
  END_INPUT

  fig('--publish remote-only/1.2.3', input)
  fig('--clean remote-only/1.2.3', input)
  fig('--publish both/1.2.3', input)
  fig('--publish-local local-only/1.2.3', input)

  return
end

def create_package_dot_fig
  File.open "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::DEFAULT_FIG_FILE}", 'w' do
    |handle|
    handle.print <<-END
      config default
        include prerequisite/1.2.3
      end
    END
  end

  return
end

def remove_any_package_dot_fig
  FileUtils.rm_rf "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::DEFAULT_FIG_FILE}"

  return
end

def test_list_configs(package_name)
  set_up_local_and_remote_repository

  (out, err, exitstatus) = fig("--list-configs #{package_name}/1.2.3")
  exitstatus.should == 0
  out.should == "default\nnondefault"
  err.should == ''

  return
end

describe 'Fig' do
  describe '--list-local' do
    it %q<prints nothing with an empty repository> do
      cleanup_home_and_remote

      (out, err, exitstatus) = fig('--list-local')
      exitstatus.should == 0
      out.should == ''
      err.should == ''
    end

    it %q<prints only local packages> do
      set_up_local_and_remote_repository

      (out, err, exitstatus) = fig('--list-local')
      exitstatus.should == 0
      out.should == "both/1.2.3\nlocal-only/1.2.3\nprerequisite/1.2.3"
      err.should == ''
    end

    it 'should complain if with a package descriptor' do
      cleanup_home_and_remote
      out, err, exit_code = fig('--list-local foo', nil, :no_raise_on_error)
      out.should_not be_empty
      exit_code.should_not == 0
    end
  end

  describe '--list-remote' do
    it %q<prints nothing with an empty repository> do
      cleanup_home_and_remote

      (out, err, exitstatus) = fig('--list-remote')
      exitstatus.should == 0
      out.should == ''
      err.should == ''
    end

    it %q<prints only remote packages> do
      set_up_local_and_remote_repository

      (out, err, exitstatus) = fig('--list-remote')
      exitstatus.should == 0
      out.should == "both/1.2.3\nprerequisite/1.2.3\nremote-only/1.2.3"
      err.should == ''
    end

    it 'should complain if with a package descriptor' do
      cleanup_home_and_remote
      out, err, exit_code = fig('--list-remote foo', nil, :no_raise_on_error)
      out.should_not be_empty
      exit_code.should_not == 0
    end
  end

  describe '--list-configs' do
    it %q<prints all the configurations for local-only> do
      test_list_configs('local-only')
    end

    it %q<prints all the configurations for both> do
      test_list_configs('both')
    end

    it %q<prints all the configurations for remote-only> do
      set_up_local_and_remote_repository

      (out, err, exitstatus) =
        fig("--list-configs remote-only}/1.2.3", nil, :no_raise_on_error)
      exitstatus.should_not == 0
      out.should =~ /Fig file not found for package/
    end
  end

  describe '--list-dependencies' do
    it %q<lists only the current package and not all in the repository without a package.fig> do
      set_up_local_and_remote_repository
      remove_any_package_dot_fig

      (out, err, exitstatus) = fig('--list-dependencies local-only/1.2.3')
      exitstatus.should == 0
      out.should == 'prerequisite/1.2.3'
      err.should == ''
    end

    it %q<lists only the current package and not all in the repository with a package.fig> do
      set_up_local_and_remote_repository
      create_package_dot_fig

      (out, err, exitstatus) = fig('--list-dependencies')
      exitstatus.should == 0
      out.should == 'prerequisite/1.2.3'
      err.should == ''
    end

    it %q<lists nothing when there are no dependencies (and output is not a tty)> do
      set_up_local_and_remote_repository
      remove_any_package_dot_fig

      (out, err, exitstatus) = fig('--list-dependencies prerequisite/1.2.3')
      exitstatus.should == 0
      out.should == ''
      err.should == ''
    end
  end
end
