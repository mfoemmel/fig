require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  describe 'package definition dumping' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    describe '--dump-package-definition-text' do
      it %q<dumps the contents of a published package> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END
        fig(%w<--publish foo/1.2.3>, input)

        (out, err, exit_status) =
          fig(%w<foo/1.2.3 --dump-package-definition-text>)

        # Content from the input.
        out.should =~ /set FOO=BAR/

        # Content that is added by publishing.
        out.should =~ /publishing information for/i

        err.should == ''
      end

      it %q<dumps the contents an unpublished package> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END
        (out, err, exit_status) =
          fig(%w<--dump-package-definition-text>, input)

        out.should == input.strip
        err.should == ''
      end

      it %q<fails if there is no text> do
        (out, err, exit_status) =
          fig(%w<--dump-package-definition-text>, :no_raise_on_error => true)
        err.should =~ /no text/
        out.should == ''
        exit_status.should_not == 0
      end
    end

    describe '--dump-package-definition-parsed' do
      it %q<dumps the contents of a published package> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END
        fig(%w<--publish foo/1.2.3>, input)

        (out, err, exit_status) =
          fig(%w<foo/1.2.3 --dump-package-definition-parsed>)

        # Content from the input.
        out.should =~ /set FOO=BAR/

        err.should == ''
      end

      it %q<dumps the contents an unpublished package> do
        input = <<-END
          config default
            set FOO=BAR
          end
        END
        (out, err, exit_status) =
          fig(%w<--dump-package-definition-parsed>, input)

        [input, out].each do
          |string|

          string.gsub!(/^[ ]+/, '')
          string.gsub!(/[ ]+/, ' ')
          string.strip!
        end

        out.should == input
        err.should == ''
      end

      it %q<emits the synthetic package if there is no text> do
        (out, err, exit_status) = fig(%w<--dump-package-definition-parsed>)
        out.should =~ / \A \s* config \s+ default \s+ end \s* \z /x
        err.should == ''
      end
    end
  end
end
