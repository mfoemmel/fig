require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/operating_system'
require 'fig/repository'

ECHO_COMMAND = Fig::OperatingSystem.windows? ? '@echo' : 'echo'

describe 'Fig' do
  describe 'publishing (without retrieval)' do
    context 'starting with a clean home and remote repository' do
      before(:each) do
        clean_up_test_environment
        set_up_test_environment
        cleanup_home_and_remote
      end

      it 'complains when multiple assets have the same base name' do
        input = <<-END
          archive http://some-host/duplicate-archive.tar.gz
          archive http://some-other-host/duplicate-archive.tar.gz
          config default end
        END

        out, err, exit_code =
            fig('--publish foo/1.2.3', input, :no_raise_on_error => true)

        err.should =~ /multiple archives/
        err.should =~ /duplicate-archive\.tar\.gz/
        exit_code.should_not == 0
      end

      it 'complains when archives are named the same as the resources tarball' do
        %w< archive resource >.each do
          |statement_type|

          input = <<-END
            #{statement_type} http://some-host/#{Fig::Repository::RESOURCES_FILE}
            config default end
          END

          out, err, exit_code =
              fig('--publish foo/1.2.3', input, :no_raise_on_error => true)

          err.should =~
            /cannot have an asset with the name "#{Regexp.escape(Fig::Repository::RESOURCES_FILE)}"/
          exit_code.should_not == 0
        end
      end

      it 'publishes to remote repository' do
        input = <<-END
          config default
            set FOO=BAR
          end
        END

        fig('--publish foo/1.2.3', input)
      end

      it %q<--publish should complain if local repository isn't in the expected format version> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END

        set_local_repository_format_to_future_version()
        out, err, exit_code =
            fig('--publish foo/1.2.3', input, :no_raise_on_error => true)
        err.should =~
          /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
        exit_code.should_not == 0
      end

      it %q<--publish-local should complain if local repository isn't in the expected format version> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END

        set_local_repository_format_to_future_version()
        out, err, exit_code =
            fig('--publish-local foo/1.2.3', input, :no_raise_on_error => true)
        err.should =~
          /Local repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
        exit_code.should_not == 0
      end

      it %q<complains if remote repository isn't in the expected format version> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END

        set_remote_repository_format_to_future_version()
        out, err, exit_code =
            fig('--publish foo/1.2.3', input, :no_raise_on_error => true)
        err.should =~
          /Remote repository is in version \d+ format. This version of fig can only deal with repositories in version \d+ format\./
        exit_code.should_not == 0
      end

      describe 'overrides' do
        before(:each) do
          [3, 4, 5, 'command-line'].each do |point_ver|
            fig("--publish foo/1.2.#{point_ver} --set FOO=foo-v1.2.#{point_ver}")
          end

          [0,1].each do |point_ver|
            fig("--publish blah/2.0.#{point_ver} --set BLAH=bla20#{point_ver}")
          end

          input = <<-END
            config default
              include :nondefault
            end
            config nondefault
              include foo/1.2.3
              include blah/2.0.0
            end
          END
          fig('--publish bar/4.5.6', input)

          input = <<-END
            # Multiple overrides will work for 'default', even if
            # indirectly specified.
            config default
              include :nondefault
            end
            config nondefault
              include foo/1.2.4
              include blah/2.0.1
            end
          END
          fig('--publish baz/7.8.9', input)

          input = <<-END
            config default
              include foo/1.2.5
            end
          END
          fig('--publish cat/10.11.12', input)

          input = <<-END
            config default
              include bar/4.5.6

              # Description of "multiple overrides" below out of date, however
              # we need to ensure we don't break old package.fig files. Thus,
              # we leave override statements on the same line as the include
              # statements because overrides used to be part of include
              # statements instead of being independent.

              # Demonstrates the syntax for how a package overrides multiple
              # dependencies (assuming the dependencies are resolved in a
              # 'default' config section).
              include baz/7.8.9:default override foo/1.2.3 override blah/2.0.0
              include cat/10.11.12 override foo/1.2.3
            end
          END
          fig('--publish top/1', input)
        end

        it 'work from a published .fig file' do
          fig('--update --include top/1 --get FOO')[0].should == 'foo-v1.2.3'
        end

        it 'work from a package published based upon a command-line' do
          fig(
            'command-line/some-version --no-file --publish --include top/1 --override foo/1.2.command-line'
          )
          fig(
            '--no-file --include command-line/some-version --get FOO'
          )[0].should == 'foo-v1.2.command-line'
        end

        it 'work from the command-line' do
          fig(
            '--update --include top/1 --override foo/1.2.command-line --get FOO'
          )[0].should ==
            'foo-v1.2.command-line'
        end

        it 'fail with conflicting versions' do
          out, err, exit_code =
            fig(
              'package/version --no-file --publish --include top/1' +
              ' --override some-package/1.2.3'                               +
              ' --override some-package/1.2.4',
              :no_raise_on_error => true
            )
          err.should =~ /version conflict/i
          err.should =~ /\bsome-package\b/
          exit_code.should_not == 0
        end
      end

      it 'complains if you publish without a package descriptor' do
        out, err, exit_code = fig('--publish', :no_raise_on_error => true)
        err.should =~ /need to specify a descriptor/i
        exit_code.should_not == 0
      end

      it 'complains if you publish without a package version' do
        out, err, exit_code = fig('--publish foo', :no_raise_on_error => true)
        err.should =~ /version required/i
        exit_code.should_not == 0
      end

      it 'refuses to overwrite existing version in remote repository without being forced' do
        input = <<-END
          config default
            set FOO=SHEEP
          end
        END
        fig('--publish foo/1.2.3', input)
        fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
        fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update --include foo/1.2.3 --get FOO')[0].should == 'SHEEP'

        input = <<-END
          config default
            set FOO=CHEESE
          end
        END
        (out, err, exitstatus) = fig(
          '--publish foo/1.2.3', input, :no_raise_on_error => true
        )
        exitstatus.should == 1
        fig('--update --include foo/1.2.3 --get FOO')[0].should == 'SHEEP'

        (out, err, exitstatus) = fig('--publish foo/1.2.3 --force', input)
        exitstatus.should == 0
        fig('--update --include foo/1.2.3 --get FOO')[0].should == 'CHEESE'
      end
    end

    context 'starting with a clean test environment' do
      before(:each) do
        clean_up_test_environment
      end

      it 'publishes resource to remote repository' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} bar" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        input = <<-END
          resource bin/hello.bat
          config default
            append PATH=@/bin
          end
        END
        fig('--publish foo/1.2.3', input)
        fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
        fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update --include foo/1.2.3 -- hello.bat')[0].should == 'bar'
      end

      it 'publishes resource to remote repository using command line' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} bar" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        fig("--publish foo/1.2.3 --resource bin/hello.bat --append PATH=@/bin")
        fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
        fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update --include foo/1.2.3 -- hello.bat')[0].should == 'bar'
      end

      it 'publishes only to the local repo when told to' do
        # This shouldn't matter because the remote repo shouldn't be looked at.
        set_remote_repository_format_to_future_version()

        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} bar" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        fig("--publish-local foo/1.2.3 --resource bin/hello.bat --append PATH=@/bin")
        fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update-if-missing --include foo/1.2.3 -- hello.bat')[0].should == 'bar'
      end

      it 'publishes a file containing an include statement without a version' do
        set_up_test_environment()

        input = <<-END_INPUT
          config default
            include foo # no version; need to be able to publish anyway. *sigh*
          end
        END_INPUT

        out, err, exit_code =
          fig('--publish foo/1.2.3', input, :no_raise_on_error => true)

        out.should == ''
        err.should =~
          /No version in the package descriptor of "foo" in an include statement \(line/
        exit_code.should == 0
      end

      it 'updates local packages if they already exist' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} sheep" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        fig('--publish-local foo/1.2.3 --resource bin/hello.bat --append PATH=@/bin')
        fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update-if-missing --include foo/1.2.3 -- hello.bat')[0].should == 'sheep'

        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} cheese" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        fig('--publish-local foo/1.2.3 --resource bin/hello.bat --append PATH=@/bin')
        fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update-if-missing --include foo/1.2.3 -- hello.bat')[0].should == 'cheese'
      end
    end
  end
end
