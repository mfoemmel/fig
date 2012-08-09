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
        fig(%w<--publish foo/1.2.3>, input, :fork => false)

        out, err =
          fig(%w<foo/1.2.3 --dump-package-definition-text>, :fork => false)

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
        out, err =
          fig(%w<--dump-package-definition-text>, input, :fork => false)

        out.should == input.strip
        err.should == ''
      end

      it %q<fails if there is no text> do
        out, err, exit_code = fig(
            %w<--dump-package-definition-text>,
            :no_raise_on_error => true,
            :fork => false
        )
        err.should =~ /no text/
        out.should == ''
        exit_code.should_not == 0
      end
    end

    describe '--dump-package-definition-parsed' do
      it %q<dumps the contents of a published package> do
        pending 'implementation of environment variable statement minimum_grammar_for_emitting_input()' do
          input = <<-END
            config default
              set FOO=BAR
            end
          END
          fig(%w<--publish foo/1.2.3>, input, :fork => false, :fork => false)

          out, err =
            fig(%w<foo/1.2.3 --dump-package-definition-parsed>, :fork => false)

          # Content from the input.
          out.should =~ /set FOO=BAR/

          err.should == ''
        end
      end

      it %q<dumps the contents an unpublished package> do
        pending 'implementation of environment variable statement minimum_grammar_for_emitting_input()' do
          input = <<-END
            config default
              set FOO=BAR
            end
          END
          out, err =
            fig(%w<--dump-package-definition-parsed>, input, :fork => false)

          [input, out].each do
            |string|

            string.gsub!(/^[ ]+/, '')
            string.gsub!(/[ ]+/, ' ')
            string.strip!
          end

          out.should be_include input
          err.should == ''
        end
      end

      it %q<emits the synthetic package if there is no text> do
        pending 'implementation of environment variable statement minimum_grammar_for_emitting_input()' do
          out, err = fig(%w<--dump-package-definition-parsed>, :fork => false)
          out.should =~ / \A \s* config \s+ default \s+ end \s* \z /x
          err.should == ''
        end
      end
    end
  end
end
