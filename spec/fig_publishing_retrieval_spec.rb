require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/operatingsystem'

describe 'Fig' do
  describe 'publishing/retrieval' do
    let(:lib_directory)      { "#{FIG_SPEC_BASE_DIRECTORY}/lib" }
    let(:retrieve_directory) { "#{FIG_SPEC_BASE_DIRECTORY}/retrieve" }

    before(:each) do
      cleanup_test_environment
      FileUtils.mkdir_p(lib_directory)
    end

    it 'retrieves resource' do
      File.open("#{lib_directory}/a-library", 'w') { |f| f << 'some library' }
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/a-library
        end
      END
      fig('--publish prerequisite/1.2.3', input)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
    end

    it 'retrieves resource and ignores the append statement in the updating config' do
      File.open("#{lib_directory}/a-library", 'w') { |f| f << 'some library' }
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/a-library
        end
      END
      fig('--publish prerequisite/1.2.3', input)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
          append FOOPATH=@/does/not/exist
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
    end

    it 'retrieves resource that is a directory' do
      File.open("#{lib_directory}/a-library", 'w') { |f| f << 'some library' }
      # To copy the contents of a directory, instead of the directory itself,
      # use '/.' as a suffix to the directory name in 'append'.
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/.
        end
      END
      fig('--publish prerequisite/1.2.3', input)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
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
      fig('--publish prerequisite/1.2.3', input)

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update', input)

      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/include/hello.h").should == 'a header file'
      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/include/hello2.h").should == 'another header file'
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
      fig('--publish prerequisite/1.2.3', input)

      FileUtils.rm_rf(FIG_SPEC_BASE_DIRECTORY + '/fighome')

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('-u', input)

      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/hello.h").should == 'a header file'
      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/hello2.h").should == 'another header file'
    end

    it 'packages multiple resources' do
      File.open("#{lib_directory}/a-library", 'w') { |f| f << 'some library' }
      File.open("#{lib_directory}/a-library2", 'w') { |f| f << 'some other library' }
      input = <<-END
        resource lib/a-library
        resource lib/a-library2
        config default
          append FOOPATH=@/lib/a-library
          append FOOPATH=@/lib/a-library2
        end
      END
      fig('--publish prerequisite/1.2.3', input)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('-m', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
      File.read("#{retrieve_directory}/prerequisite/a-library2").should == 'some other library'
    end

    it 'packages multiple resources with wildcards' do
      File.open("#{lib_directory}/foo.jar", 'w') { |f| f << 'some library' }
      File.open("#{lib_directory}/bar.jar", 'w') { |f| f << 'some other library' }
      input = <<-END
        resource **/*.jar
        config default
          append FOOPATH=@/lib/foo.jar
        end
      END
      fig('--publish prerequisite/1.2.3', input)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/foo.jar").should == 'some library'
    end

    it 'warns on unused retrieval' do
      setup_test_environment()

      input = <<-END
        retrieve UNREFERENCED_VARIABLE->somewhere
        config default
          set WHATEVER=SOMETHING
        end
      END
      out, err, exit_code = fig('--update-if-missing', input)

      err.should =~ /UNREFERENCED_VARIABLE.*was never referenced.*retrieve UNREFERENCED_VARIABLE->somewhere.*was ignored/
    end
  end
end
