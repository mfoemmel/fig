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

def set_up_local_and_remote_repository_with_depends_on_everything
  set_up_local_and_remote_repository

  input = <<-END_INPUT
    config default
      include :everything
    end

    config everything
      include prerequisite/1.2.3
      include local-only/1.2.3
      include remote-only/1.2.3
      include both/1.2.3
    end
  END_INPUT

  fig('--update-if-missing --publish depends-on-everything/1.2.3', input)

  input = <<-END_INPUT
    config default
    end

    config indirectly-everything
      include depends-on-everything/1.2.3:everything
    end
  END_INPUT

  fig(
    '--update-if-missing --publish depends-on-depends-on-everything/1.2.3',
    input
  )

  return
end

def create_package_dot_fig(package_name, config = nil)
  config = config ? config = ':' + config : ''

  File.open "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::DEFAULT_FIG_FILE}", 'w' do
    |handle|
    handle.print <<-END
      config default
        include #{package_name}/1.2.3#{config}
      end
    END
  end

  return
end

def create_package_dot_fig_with_single_dependency()
  create_package_dot_fig('prerequisite')
end

def create_package_dot_fig_with_all_dependencies()
  create_package_dot_fig('depends-on-everything', 'default')
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
    describe 'no --list-tree' do
      it %q<lists nothing when there are no dependencies without a package.fig (and output is not a tty)> do
        set_up_local_and_remote_repository_with_depends_on_everything
        remove_any_package_dot_fig

        (out, err, exitstatus) = fig('--list-dependencies prerequisite/1.2.3')
        exitstatus.should == 0
        out.should == ''
        err.should == ''
      end

      it %q<lists only the single dependency and not all in the repository with a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        create_package_dot_fig_with_single_dependency

        (out, err, exitstatus) = fig('--list-dependencies')
        exitstatus.should == 0
        out.should == 'prerequisite/1.2.3'
        err.should == ''
      end

      it %q<lists almost all packages in the repository without a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        remove_any_package_dot_fig

        (out, err, exitstatus) = fig(
          '--list-dependencies depends-on-depends-on-everything/1.2.3:indirectly-everything'
        )
        exitstatus.should == 0
        out.should ==
          "both/1.2.3\ndepends-on-everything/1.2.3:everything\nlocal-only/1.2.3\nprerequisite/1.2.3\nremote-only/1.2.3"
        err.should == ''
      end

      it %q<lists all packages in the repository with a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        create_package_dot_fig_with_all_dependencies

        (out, err, exitstatus) = fig('--list-dependencies')
        exitstatus.should == 0
        out.should ==
          "both/1.2.3\ndepends-on-everything/1.2.3:everything\nlocal-only/1.2.3\nprerequisite/1.2.3\nremote-only/1.2.3"
        err.should == ''
      end
    end

    describe 'with --list-tree' do
      it %q<lists the package when there are no dependencies without a package.fig (and output is not a tty)> do
        set_up_local_and_remote_repository_with_depends_on_everything
        remove_any_package_dot_fig

        (out, err, exitstatus) = fig('--list-dependencies --list-tree prerequisite/1.2.3')
        exitstatus.should == 0
        out.should == 'prerequisite/1.2.3'
        err.should == ''
      end

      it %q<lists only the package and the dependency and not all in the repository with a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        create_package_dot_fig_with_single_dependency

        expected = <<-END_EXPECTED_OUTPUT
<unpublished>
    prerequisite/1.2.3
        END_EXPECTED_OUTPUT
        expected.chomp!

        (out, err, exitstatus) = fig('--list-dependencies --list-tree')
        exitstatus.should == 0
        out.should == expected
        err.should == ''
      end

      it %q<lists almost all packages in the repository without a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        remove_any_package_dot_fig

        expected = <<-END_EXPECTED_OUTPUT
depends-on-depends-on-everything/1.2.3:indirectly-everything
    depends-on-everything/1.2.3:everything
        both/1.2.3
            prerequisite/1.2.3
        local-only/1.2.3
            prerequisite/1.2.3
        prerequisite/1.2.3
        remote-only/1.2.3
            prerequisite/1.2.3
        END_EXPECTED_OUTPUT
        expected.chomp!

        (out, err, exitstatus) = fig(
          '--list-dependencies --list-tree depends-on-depends-on-everything/1.2.3:indirectly-everything'
        )
        exitstatus.should == 0
        out.should == expected
        err.should == ''
      end

      it %q<lists all packages in the repository with a package.fig> do
        set_up_local_and_remote_repository_with_depends_on_everything
        create_package_dot_fig_with_all_dependencies

        expected = <<-END_EXPECTED_OUTPUT
<unpublished>
    depends-on-everything/1.2.3:everything
        both/1.2.3
            prerequisite/1.2.3
        local-only/1.2.3
            prerequisite/1.2.3
        prerequisite/1.2.3
        remote-only/1.2.3
            prerequisite/1.2.3
        END_EXPECTED_OUTPUT
        expected.chomp!

        (out, err, exitstatus) = fig('--list-dependencies --list-tree')
        exitstatus.should == 0
        out.should == expected
        err.should == ''
      end
    end
  end
end
