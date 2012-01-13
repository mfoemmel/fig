require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

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

def set_up_multiple_config_repository
  cleanup_home_and_remote

  input = <<-END_INPUT
    config default
    end
  END_INPUT
  fig('--publish no-dependencies/1.2.3', input)

  input = <<-END_INPUT
    config windows
      set OS=Windows
    end

    config ubuntu
      set OS=Linux
    end

    config redhat
      set OS=Linux
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/45
    end
  END_INPUT
  fig('--publish operatingsystem/1.2.3:windows', input)

  # Ensure we have a case where two different configs's dependencies conflict.
  fig('--publish operatingsystem/3.4.5:redhat', input)

  input = <<-END_INPUT
    config oracle
      include operatingsystem/1.2.3:redhat
    end

    config postgresql
      include operatingsystem/3.4.5:ubuntu
    end

    config sqlserver
      include operatingsystem/1.2.3:windows
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/942.29024.2939.209.1
    end
  END_INPUT
  fig('--publish database/1.2.3:oracle', input)

  input = <<-END_INPUT
    config apache
      include operatingsystem/1.2.3:redhat
    end

    config lighttpd
      include operatingsystem/3.4.5:ubuntu
    end

    config iis
      include operatingsystem/1.2.3:windows
    end

    config unreferenced
      include this-should-not-show-up-in-any-output/23.123.63.23
    end
  END_INPUT
  fig('--publish web/1.2.3:apache', input)

  input = <<-END_INPUT
    config accounting
      include database/1.2.3:oracle
      include web/1.2.3:apache
    end

    config marketing
      include database/1.2.3:postgresql
      include web/1.2.3:lighttpd
    end

    config legal
      include database/1.2.3:sqlserver
      include web/1.2.3:iis
    end
  END_INPUT
  fig('--publish departments/1.2.3:accounting', input)

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
    before(:each) do
      setup_test_environment
      cleanup_home_and_remote
    end

    it %q<prints nothing with an empty repository> do
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
      out, err, exit_code = fig('--list-local foo', nil, :no_raise_on_error)
      out.should_not be_empty
      exit_code.should_not == 0
    end
  end

  describe '--list-remote' do
    before(:each) do
      setup_test_environment
      cleanup_home_and_remote
    end

    it %q<prints nothing with an empty repository> do
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
      out, err, exit_code = fig('--list-remote foo', nil, :no_raise_on_error)
      out.should_not be_empty
      exit_code.should_not == 0
    end
  end

  describe '--list-configs' do
    before(:each) do
      setup_test_environment
      cleanup_home_and_remote
    end

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
      describe 'no --list-all-configs' do
        before(:each) do
          setup_test_environment
          cleanup_home_and_remote
        end

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

        expected = <<-END_EXPECTED_OUTPUT
both/1.2.3
depends-on-everything/1.2.3:everything
local-only/1.2.3
prerequisite/1.2.3
remote-only/1.2.3
        END_EXPECTED_OUTPUT
        expected.chomp!

          (out, err, exitstatus) = fig('--list-dependencies')
          exitstatus.should == 0
          out.should == expected
          err.should == ''
        end
      end

      describe 'with --list-all-configs' do
        before(:each) do
          setup_test_environment
          cleanup_home_and_remote
        end

        it %q<lists only the single configuration when there are no dependencies without a package.fig> do
          set_up_multiple_config_repository
          remove_any_package_dot_fig

          expected = <<-END_EXPECTED_OUTPUT
no-dependencies/1.2.3
          END_EXPECTED_OUTPUT
          expected.chomp!

          (out, err, exitstatus) = fig(
            '--list-dependencies --list-all-configs no-dependencies/1.2.3'
          )
          exitstatus.should == 0
          out.should == expected
          err.should == ''
        end

        it %q<lists only the single dependency and not all in the repository with a package.fig> do
          set_up_multiple_config_repository
          create_package_dot_fig('no-dependencies')

          expected = <<-END_EXPECTED_OUTPUT
no-dependencies/1.2.3
          END_EXPECTED_OUTPUT
          expected.chomp!

          (out, err, exitstatus) = fig('--list-dependencies --list-all-configs')
          exitstatus.should == 0
          out.should == expected
          err.should == ''
        end

# TODO: Environment needs to handle multiple package versions.
#        it %q<lists all recursive configuration dependencies without a package.fig> do
#          set_up_multiple_config_repository
#          remove_any_package_dot_fig
#
#        expected = <<-END_EXPECTED_OUTPUT
#departments/1.2.3:accounting
#departments/1.2.3:legal
#departments/1.2.3:marketing
#        END_EXPECTED_OUTPUT
#        expected.chomp!
#
#          (out, err, exitstatus) = fig(
#            '--list-dependencies --list-all-configs departments/1.2.3:legal'
#          )
#          exitstatus.should == 0
#          out.should == expected
#          err.should == ''
#        end
#
#        it %q<lists all packages in the repository with a package.fig> do
#          set_up_local_and_remote_repository_with_depends_on_everything
#          create_package_dot_fig_with_all_dependencies
#
#          (out, err, exitstatus) = fig('--list-dependencies --list-all-configs')
#          exitstatus.should == 0
#          out.should ==
#            "both/1.2.3\ndepends-on-everything/1.2.3:everything\nlocal-only/1.2.3\nprerequisite/1.2.3\nremote-only/1.2.3"
#          err.should == ''
#        end
      end
    end

    describe 'with --list-tree' do
      before(:each) do
        setup_test_environment
        cleanup_home_and_remote
      end

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
