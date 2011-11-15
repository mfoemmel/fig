require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

require 'fig/os'

setup_repository

describe 'Fig' do
  it 'sets environment variable from command line' do
    fig('-s FOO=BAR -g FOO')[0].should == 'BAR'
    fig('--set FOO=BAR -g FOO')[0].should == 'BAR'
  end

  it 'sets environment variable from fig file' do
    input = <<-END
      config default
        set FOO=BAR
      end
    END
    fig('-g FOO', input)[0].should == 'BAR'
  end

  it 'appends environment variable from command line' do
    fig('-p PATH=foo -g PATH').should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}", '', 0]
  end

  it 'appends environment variable from fig file' do
    input = <<-END
      config default
        add PATH=foo
      end
    END
    fig('-g PATH', input).should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}", '', 0]
  end

  it 'appends empty environment variable' do
    fig('-p XYZZY=foo -g XYZZY').should == ['foo', '', 0]
  end

  it 'ignores comments' do
    input = <<-END
      #/usr/bin/env fig

      # Some comment
      config default
        set FOO=BAR # Another comment
      end
    END
    fig('-g FOO', input)[0].should == 'BAR'
  end

  it 'publishes to remote repository' do
    cleanup_home_and_remote
    input = <<-END
      config default
        set FOO=BAR
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
    fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'BAR'
  end

  it 'allows single and multiple override' do
    cleanup_home_and_remote
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

    fig('-u -i top/1 -g FOO')[0].should == 'foo123'
  end

  it 'publishes resource to remote repository' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello", 'w') { |f| f << 'echo bar' }
    fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello"
    input = <<-END
      resource bin/hello
      config default
        append PATH=@/bin
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
    fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-u -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it 'publishes resource to remote repository using command line' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello", 'w') { |f| f << 'echo bar' }
    fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello"
    fig("--publish foo/1.2.3 --resource bin/hello --append PATH=@/bin")
    fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
    fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-u -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it 'refuses to overwrite existing version in remote repository without being forced' do
    cleanup_home_and_remote
    input = <<-END
      config default
        set FOO=SHEEP
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + '/repos/foo/1.2.3/.fig'
    fail unless File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'SHEEP'

    input = <<-END
      config default
        set FOO=CHEESE
      end
    END
    (out, err, exitstatus) = fig(
      '--publish foo/1.2.3', input, :no_raise_on_error
    )
    exitstatus.should == 1
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'SHEEP'

    (out, err, exitstatus) = fig('--publish foo/1.2.3 --force', input)
    exitstatus.should == 0
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'CHEESE'
  end

  it 'publishes to the local repo only when told to' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello", 'w') { |f| f << 'echo bar' }
    fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello"
    fig("--publish-local foo/1.2.3 --resource bin/hello --append PATH=@/bin")
    fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-m -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it 'retrieves resource' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/hello", 'w') { |f| f << 'some library' }
    input = <<-END
      resource lib/hello
      config default
        append FOOPATH=@/lib/hello
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
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/hello").should == 'some library'
  end

  it 'retrieves resource that is a directory' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/hello", 'w') { |f| f << 'some library' }
    # To copy the contents of a directory, instead of the directory itself,
    # use '/.' as a suffix to the directory name in 'append'.
    input = <<-END
      resource lib/hello
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
    fig('-m', input)
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/hello").should == 'some library'
  end

  it %q<preserves the path after '//' when copying files into your project directory while retrieving> do
    cleanup_repository
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
    fig('-u', input)

    File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/include/hello.h").should == 'a header file'
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/foo/include/hello2.h").should == 'another header file'
  end

  it 'packages multiple resources' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/lib")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/hello", 'w') { |f| f << 'some library' }
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/lib/hello2", 'w') { |f| f << 'some other library' }
    input = <<-END
      resource lib/hello
      resource lib/hello2
      config default
        append FOOPATH=@/lib/hello
        append FOOPATH=@/lib/hello2
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
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/hello").should == 'some library'
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/hello2").should == 'some other library'
  end

  it 'packages multiple resources with wildcards' do
    cleanup_repository
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
    fig('-m', input)
    File.read("#{FIG_SPEC_BASE_DIRECTORY}/lib2/foo/foo.jar").should == 'some library'
  end

  it 'updates local packages if they already exist' do
    cleanup_repository
    FileUtils.mkdir_p("#{FIG_SPEC_BASE_DIRECTORY}/bin")
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello", 'w') { |f| f << 'echo sheep' }
    fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello"
    fig('--publish-local foo/1.2.3 --resource bin/hello --append PATH=@/bin')
    fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-m -i foo/1.2.3 -- hello')[0].should == 'sheep'

    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bin/hello", 'w') { |f| f << 'echo cheese' }
    fail unless system "chmod +x #{FIG_SPEC_BASE_DIRECTORY}/bin/hello"
    fig('--publish-local foo/1.2.3 --resource bin/hello --append PATH=@/bin')
    fail if File.exists? FIG_REMOTE_DIR + '/foo/1.2.3/.fig'
    fig('-m -i foo/1.2.3 -- hello')[0].should == 'cheese'
  end

  it 'prints the version number' do
    %w/-v --version/.each do |option|
      (out, err, exitstatus) = fig(option)
      exitstatus.should == 0
      err.should == ''
      out.should =~ / \d+ \. \d+ \. \d+ /x
    end
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
    File.open "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::DEFAULT_FIG_FILE}", 'w' do
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
end
