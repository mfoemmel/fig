# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe 'suppress unversioned include statement warnings' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
      cleanup_home_and_remote

      input = <<-END
        config default
        end
      END

      out, err = fig(%w<--publish bar/1.2.3>, input)

      input = <<-END
        config default
          include bar/1.2.3
        end

        config non-default
          include bar
        end
      END

      out, err = fig(%w<--publish foo/1.2.3>, input)
    end

    describe 'emits warnings when warnings are not suppressed' do
      it 'for the package.fig' do
        input = <<-END
          config default
            include foo
          end
        END

        out, err = fig(%w<--list-configs>, input)
        out.should == 'default'
        err.should =~ /No version in the package descriptor of "foo" in an include statement \(line/
      end

      it 'for depended upon packages' do
        input = <<-END
          config default
            include foo/1.2.3
          end
        END

        out, err = fig(%w<--list-dependencies>, input)
        out.should == "bar/1.2.3\nfoo/1.2.3"
        err.should =~ %r<No version in the package descriptor of "bar" in an include statement in the \.fig file for "foo/1\.2\.3:default" \(line>
      end
    end

    describe 'emits warning for base package even when warnings are suppressed' do
      it 'with --suppress-warning-include-statement-missing-version' do
        input = <<-END
          config default
            include foo
          end
        END

        out, err = fig(
          %w<
            --list-configs
            --suppress-warning-include-statement-missing-version
          >,
          input
        )
        out.should == 'default'
        err.should =~ /No version in the package descriptor of "foo" in an include statement \(line/
      end

      it 'with figrc' do
        figrc = File.join(FIG_SPEC_BASE_DIRECTORY, 'test-figrc')
        File.open(figrc, 'w') do
          |handle|
          handle.puts %q< { "suppress warnings": ["include statement missing version"] } >
        end

        input = <<-END
          config default
            include foo
          end
        END

        out, err = fig(%w<--list-configs>, input)
        out.should == 'default'
        err.should =~ /No version in the package descriptor of "foo" in an include statement \(line/
      end
    end

    describe 'does not emit warning for depended upon packages when warnings are suppressed' do
      it 'with --suppress-warning-include-statement-missing-version' do
        input = <<-END
          config default
            include foo/1.2.3
          end
        END

        out, err = fig(
          %w<
            --list-dependencies
            --suppress-warning-include-statement-missing-version
          >,
          input
        )
        out.should == "bar/1.2.3\nfoo/1.2.3"
        err.should_not =~ /No version in the package descriptor of "bar" in an include statement/
      end

      it 'with figrc' do
        figrc = File.join(FIG_SPEC_BASE_DIRECTORY, 'test-figrc')
        File.open(figrc, 'w') do
          |handle|
          handle.puts %q< { "suppress warnings": ["include statement missing version"] } >
        end

        input = <<-END
          config default
            include foo/1.2.3
          end
        END

        out, err = fig(%w<--list-dependencies>, input, :figrc => figrc)
        out.should == "bar/1.2.3\nfoo/1.2.3"
        err.should_not =~ /No version in the package descriptor of "bar" in an include statement/
      end
    end
  end
end
