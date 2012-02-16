require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/operatingsystem'

ECHO_COMMAND = Fig::OperatingSystem.windows? ? '@echo' : 'echo'

describe 'Fig' do
  describe 'publishing/retrieval' do
    context 'starting with a clean home and remote repository' do
      before(:each) do
        cleanup_test_environment
        setup_test_environment
        cleanup_home_and_remote
      end

      it 'publishes to remote repository' do
        input = <<-END
          config default
            set FOO=BAR
          end
        END

        fig('--publish foo/1.2.3', input)
        fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
        fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update --include foo/1.2.3 --get FOO')[0].should == 'BAR'
      end

      it 'allows single and multiple override' do
        [3,4,5].each do |point_ver|   # Publish some versions of foo
          input = <<-END
            config default
              set FOO=foo12#{point_ver}
            end
          END
          fig("--publish foo/1.2.#{point_ver}", input)
        end

        [0,1].each do |point_ver|    # Publish some versions of blah
          input = <<-END
            config default
              set BLAH=bla20#{point_ver}
            end
          END
          fig("--publish blah/2.0.#{point_ver}", input)
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
            # Demonstrates the syntax for how a package overrides multiple dependencies
            # (assuming the dependencies are resolved in a 'default' config section)
            include baz/7.8.9:default override foo/1.2.3 override blah/2.0.0
            include cat/10.11.12 override foo/1.2.3
          end
        END
        fig('--publish top/1', input)

        fig('--update --include top/1 --get FOO')[0].should == 'foo123'
      end

      it 'should complain if you publish without a package descriptor' do
        out, err, exit_code = fig('--publish', nil, :no_raise_on_error)
        err.should_not be_empty
        exit_code.should_not == 0
      end

      it 'should complain if you publish without a package version' do
        out, err, exit_code = fig('--publish foo', nil, :no_raise_on_error)
        err.should_not be_empty
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
          '--publish foo/1.2.3', input, :no_raise_on_error
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
        cleanup_test_environment
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

      it 'publishes to the local repo only when told to' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat", 'w') { |f| f << "#{ECHO_COMMAND} bar" }
        if Fig::OperatingSystem.unix?
          fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello.bat"
        end
        fig("--publish-local foo/1.2.3 --resource bin/hello.bat --append PATH=@/bin")
        fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
        fig('--update-if-missing --include foo/1.2.3 -- hello.bat')[0].should == 'bar'
      end

      it 'publishs a file containing an include statement without a version' do
        setup_test_environment()

        input = <<-END_INPUT
          config default
            include foo # no version; need to be able to publish anyway. *sigh*
          end
        END_INPUT

        out, err, exit_code = fig('--publish foo/1.2.3', input, :no_raise_on_error)

        out.should == ''
        err.should =~
          /No version in the package descriptor of "foo" in an include statement in the \.fig file for "" \(line/
        exit_code.should == 0
      end

      it 'retrieves resource' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/a-library", 'w') { |f| f << 'some library' }
        input = <<-END
          resource lib/a-library
          config default
            append FOOPATH=@/lib/a-library
          end
        END
        fig('--publish foo/1.2.3', input)
        input = <<-END
          retrieve FOOPATH->lib2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('--update-if-missing', input)
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/a-library").should == 'some library'
      end

      it 'retrieves resource and ignores the append statement in the updating config' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/a-library", 'w') { |f| f << 'some library' }
        input = <<-END
          resource lib/a-library
          config default
            append FOOPATH=@/lib/a-library
          end
        END
        fig('--publish foo/1.2.3', input)
        input = <<-END
          retrieve FOOPATH->lib2/[package]
          config default
            include foo/1.2.3
            append FOOPATH=@/does/not/exist
          end
        END
        fig('--update-if-missing', input)
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/a-library").should == 'some library'
      end


      it 'retrieves resource that is a directory' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/a-library", 'w') { |f| f << 'some library' }
        # To copy the contents of a directory, instead of the directory itself,
        # use '/.' as a suffix to the directory name in 'append'.
        input = <<-END
          resource lib/a-library
          config default
            append FOOPATH=@/lib/.
          end
        END
        fig('--publish foo/1.2.3', input)
        input = <<-END
          retrieve FOOPATH->lib2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('--update-if-missing', input)
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/a-library").should == 'some library'
      end

      it %q<preserves the path after '//' when copying files into your project directory while retrieving> do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/include")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/include/hello.h", 'w') { |f| f << 'a header file' }
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/include/hello2.h", 'w') { |f| f << 'another header file' }
        input = <<-END
          resource include/hello.h
          resource include/hello2.h
          config default
            append INCLUDE=@//include/hello.h
            append INCLUDE=@//include/hello2.h
          end
        END
        fig('--publish foo/1.2.3', input)

        input = <<-END
          retrieve INCLUDE->include2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('--update', input)

        File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/include/hello.h").should == 'a header file'
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/include/hello2.h").should == 'another header file'
      end

      it 'updates without there being a copy of the package in the FIG_HOME left there from publishing' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/include")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/include/hello.h", 'w') { |f| f << 'a header file' }
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/include/hello2.h", 'w') { |f| f << 'another header file' }
        input = <<-END
          resource include/hello.h
          resource include/hello2.h
          config default
            append INCLUDE=@/include/hello.h
            append INCLUDE=@/include/hello2.h
          end
        END
        fig('--publish foo/1.2.3', input)

        FileUtils.rm_rf(FIG_SPEC_BASE_DIRECTORY + '/fighome')

        input = <<-END
          retrieve INCLUDE->include2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('-u', input)

        File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/hello.h").should == 'a header file'
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/hello2.h").should == 'another header file'
      end

      it 'packages multiple resources' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/a-library", 'w') { |f| f << 'some library' }
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/a-library2", 'w') { |f| f << 'some other library' }
        input = <<-END
          resource lib/a-library
          resource lib/a-library2
          config default
            append FOOPATH=@/lib/a-library
            append FOOPATH=@/lib/a-library2
          end
        END
        fig('--publish foo/1.2.3', input)
        input = <<-END
          retrieve FOOPATH->lib2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('-m', input)
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/a-library").should == 'some library'
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/a-library2").should == 'some other library'
      end

      it 'packages multiple resources with wildcards' do
        FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/foo.jar", 'w') { |f| f << 'some library' }
        File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/bar.jar", 'w') { |f| f << 'some other library' }
        input = <<-END
          resource **/*.jar
          config default
            append FOOPATH=@/lib/foo.jar
          end
        END
        fig('--publish foo/1.2.3', input)
        input = <<-END
          retrieve FOOPATH->lib2/[package]
          config default
            include foo/1.2.3
          end
        END
        fig('--update-if-missing', input)
        File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/foo.jar").should == 'some library'
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
