require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/operating_system'

describe 'Fig' do
  describe 'running commands' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    describe 'in a package config section' do
      describe %q<executes the command> do
        describe %q<in a published package> do
          it %q<when not told to --run-command-statement> do
            input = <<-END
              config default
                command "echo foo"
              end
            END
            fig(%w<--publish foo/1.2.3>, input)

            out, err = fig(%w<foo/1.2.3>)
            out.should == 'foo'
            err.should == ''
          end

          it %q<when told to --run-command-statement> do
            input = <<-END
              config default
                command "echo foo"
              end
            END
            fig(%w<--publish foo/1.2.3>, input)

            out, err = fig(%w<foo/1.2.3 --run-command-statement>)
            out.should == 'foo'
            err.should == ''
          end
        end

        it %q<in the default config in an unpublished package when told to --run-command-statement> do
          input = <<-END
            config default
              command "echo foo"
            end
          END

          out, err = fig(%w<--run-command-statement>, input)
          out.should == 'foo'
          err.should == ''
        end

        it %q<in a non-default config in an unpublished package when told to --run-command-statement> do
          input = <<-END
            config default
              command "echo default"
            end

            config non-default
              command "echo non-default"
            end
          END

          out, err = fig(%w<--run-command-statement --config non-default>, input)
          out.should == 'non-default'
          err.should == ''
        end
      end

      describe %q<passes command-line arguments to the command> do
        it %q<in a published package> do
          input = <<-END
            config default
              command "echo Hi"
            end
          END
          fig(%w<--publish foo/1.2.3>, input)

          out, err = fig(%w<foo/1.2.3 --command-extra-args there>)
          out.should == 'Hi there'
          err.should == ''
        end

        describe %q<in an unpublished package> do
          it %q<when only given --command-extra-args> do
            input = <<-END
              config default
                command "echo Hi"
              end
            END

            out, err = fig(%w<--command-extra-args there>, input)
            out.should == 'Hi there'
            err.should == ''
          end

          it %q<when also given --run-command-statement> do
            input = <<-END
              config default
                command "echo Hi"
              end
            END

            out, err =
              fig(%w<--run-command-statement --command-extra-args there>, input)
            out.should == 'Hi there'
            err.should == ''
          end
        end
      end

      it %q<fails if command-line arguments specified but no command found> do
        input = <<-END
          config default
          end
        END
        fig(%w<--publish foo/1.2.3>, input)

        out, err, exit_code =
          fig(%w<foo/1.2.3 --command-extra-args yadda>, :no_raise_on_error => true)
        exit_code.should_not == 0
        out.should == ''
        err.should =~ /does not contain a command/
      end

      it %q<prints a warning message when attempting to run multiple commands> do
        input = <<-END
          config default
            command "echo foo"
            command "echo bar"
          end
        END
        out, err, exit_code =
          fig(%w<--publish foo/1.2.3.4>, input, :no_raise_on_error => true)
        err.should =~
          %r<Found a second "command" statement within a "config" block \(line>
      end

      it %q<fails with an unpublished package and --run-command-statement wasn't specified> do
        input = <<-END
          config default
            command "echo foo"
          end
        END

        out, err, exit_code = fig([], input, :no_raise_on_error => true)
        exit_code.should_not == 0
        err.should =~ /\bnothing to do\b/i
        err.should =~ /\byou have a command statement\b/i
        err.should =~ /--run-command-statement\b/i
        out.should == ''
      end
    end

    if Fig::OperatingSystem.unix?
      describe %q<from the command line> do
        it %q<via the shell if given a single argument> do
          out, err = fig(['--', 'echo foo $0 bar'])
          out.should     =~ /\A foo [ ] .+ [ ] bar \z/x
          out.should_not == 'foo $0 bar'
          err.should == ''
        end

        it %q<without the shell if given multiple arguments> do
          out, err = fig(%w<-- echo foo $0 bar>)
          out.should == 'foo $0 bar'
          err.should == ''
        end
      end
    end
  end
end
