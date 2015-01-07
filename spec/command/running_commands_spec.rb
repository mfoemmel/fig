# coding: utf-8

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
        describe %q<in a published v0 package> do
          it %q<when not told to --run-command-statement> do
            input = <<-END
              config default
                command "echo foo"
              end
            END
            fig %w<--publish foo/1.2.3>, input

            out, err = fig %w<foo/1.2.3>
            out.should == 'foo'
            err.should == ''
          end

          it %q<when told to --run-command-statement> do
            input = <<-END
              config default
                command "echo foo"
              end
            END
            fig %w<--publish foo/1.2.3>, input

            out, err = fig %w<foo/1.2.3 --run-command-statement>
            out.should == 'foo'
            err.should == ''
          end

          if Fig::OperatingSystem.unix?
            # Command statements used to be split on whitespace and put back
            # together with space characters.
            it %q<without manipulating whitespace> do
              input = <<-END
                config default
                  command "echo 'foo   bar'"
                end
              END
              fig %w<--publish foo/1.2.3>, input

              out, err = fig %w<foo/1.2.3>
              out.should == 'foo   bar'
              err.should == ''
            end
          end
        end

        describe %q<in a published v1 package> do
          it %q<when not told to --run-command-statement> do
            input = <<-END
              grammar v1
              config default
                command "echo foo" end
                set force='publishing in v1 grammar'
              end
            END
            fig %w<--publish foo/1.2.3>, input

            out, err = fig %w<foo/1.2.3>
            out.should == 'foo'
            err.should == ''
          end

          it %q<when told to --run-command-statement> do
            input = <<-END
              grammar v1
              config default
                command "echo foo" end
                set force='publishing in v1 grammar'
              end
            END
            fig %w<--publish foo/1.2.3>, input

            out, err = fig %w<foo/1.2.3 --run-command-statement>
            out.should == 'foo'
            err.should == ''
          end

          if Fig::OperatingSystem.unix?
            # Command statements used to be split on whitespace and put back
            # together with space characters.
            it %q<without manipulating whitespace> do
              input = <<-END
                grammar v1
                config default
                  command "echo 'foo   bar'" end
                  set force='publishing in v1 grammar'
                end
              END
              fig %w<--publish foo/1.2.3>, input

              out, err = fig %w<foo/1.2.3>
              out.should == 'foo   bar'
              err.should == ''
            end
          end
        end

        it %q<in the default config in an unpublished v0 package when told to --run-command-statement> do
          input = <<-END
            config default
              command "echo foo"
            end
          END

          out, err = fig %w<--run-command-statement>, input
          out.should == 'foo'
          err.should == ''
        end

        it %q<in the default config in an unpublished v1 package when told to --run-command-statement> do
          input = <<-END
            grammar v1
            config default
              command "echo foo" end
            end
          END

          out, err = fig %w<--run-command-statement>, input
          out.should == 'foo'
          err.should == ''
        end

        it %q<in a non-default config in an unpublished v0 package when told to --run-command-statement> do
          input = <<-END
            config default
              command "echo default"
            end

            config non-default
              command "echo non-default"
            end
          END

          out, err = fig %w<--run-command-statement --config non-default>, input
          out.should == 'non-default'
          err.should == ''
        end

        it %q<in a non-default config in an unpublished v1 package when told to --run-command-statement> do
          input = <<-END
            grammar v1
            config default
              command "echo default" end
            end

            config non-default
              command "echo non-default" end
            end
          END

          out, err = fig %w<--run-command-statement --config non-default>, input
          out.should == 'non-default'
          err.should == ''
        end
      end

      describe %q<passes command-line arguments to the command> do
        it %q<in a published v0 package> do
          input = <<-END
            config default
              command "echo Hi"
            end
          END
          fig %w<--publish foo/1.2.3>, input

          out, err = fig %w<foo/1.2.3 --command-extra-args there>
          out.should == 'Hi there'
          err.should == ''
        end

        it %q<in a published v1 package with a single command-line component> do
          input = <<-END
            grammar v1
            config default
              command "echo Hi" end
              set force='publishing in v1 grammar'
            end
          END
          fig %w<--publish foo/1.2.3>, input

          out, err = fig %w<foo/1.2.3 --command-extra-args there>
          out.should == 'Hi there'
          err.should == ''
        end

        if Fig::OperatingSystem.unix?
          # "echo" does not exist outside of the command interpreter on Windows.
          it %q<in a published v1 package with multiple command-line components> do
            input = <<-END
              grammar v1
              config default
                command echo Hi, won\\'t "you" 'be  my' end
              end
            END
            fig %w<--publish foo/1.2.3>, input

            out, err = fig %w<foo/1.2.3 --command-extra-args neighbor?>
            out.should == %q<Hi, won't you be  my neighbor?>
            err.should == ''
          end
        end

        describe %q<in an unpublished package> do
          it %q<when only given --command-extra-args with the v0 grammar> do
            input = <<-END
              config default
                command "echo Hi"
              end
            END

            out, err = fig %w<--command-extra-args there>, input
            out.should == 'Hi there'
            err.should == ''
          end

          if Fig::OperatingSystem.unix?
            # "echo" does not exist outside of the command interpreter on Windows.
            it %q<when only given --command-extra-args with the v1 grammar> do
              input = <<-END
                grammar v1
                config default
                  command echo Hi end
                end
              END

              out, err = fig %w<--command-extra-args there>, input
              out.should == 'Hi there'
              err.should == ''
            end
          end

          it %q<when also given --run-command-statement with the v0 grammar> do
            input = <<-END
              config default
                command "echo Hi"
              end
            END

            out, err =
              fig %w<--run-command-statement --command-extra-args there>, input
            out.should == 'Hi there'
            err.should == ''
          end

          if Fig::OperatingSystem.unix?
            # Cannot figure out the quoting to get this to work on Windows.
            it %q<when also given --run-command-statement with the v1 grammar> do
              input = <<-END
                grammar v1
                config default
                  command "echo 'Hi" end
                end
              END

              out, err = fig(
                [%w<--run-command-statement --command-extra-args>, %q< there\\'>],
                input
              )
              # Two spaces due to command-line concatenation and running through
              # the shell.
              out.should == 'Hi  there'
              err.should == ''
            end
          end
        end
      end

      describe 'fails' do
        it %q<if command-line arguments specified but no command statement found> do
          input = <<-END
            config default
            end
          END
          fig %w<--publish foo/1.2.3>, input

          out, err, exit_code = fig(
            %w<foo/1.2.3 --command-extra-args yadda>,
            :no_raise_on_error => true
          )
          out.should == ''
          err.should =~ /does not contain a command/
          exit_code.should_not == 0
        end

        it %q<if it finds multiple command statements> do
          input = <<-END
            config default
              command "echo foo"
              command "echo bar"
            end
          END
          out, err, exit_code =
            fig %w<--publish foo/1.2.3.4>, input, :no_raise_on_error => true
          err.should =~
            %r<Found a second "command" statement within a "config" block \(line>
          exit_code.should_not == 0
        end

        it %q<with an unpublished package and --run-command-statement wasn't specified> do
          input = <<-END
            config default
              command "echo foo"
            end
          END

          out, err, exit_code = fig [], input, :no_raise_on_error => true
          err.should =~ /\bnothing to do\b/i
          err.should =~ /\byou have a command statement\b/i
          err.should =~ /--run-command-statement\b/i
          out.should == ''
          exit_code.should_not == 0
        end
      end
    end

    if Fig::OperatingSystem.unix?
      describe %q<from the command line> do
        it %q<via the shell if given a single argument> do
          out, err = fig ['--', 'echo foo $0 bar']
          out.should     =~ /\A foo [ ] .+ [ ] bar \z/x
          out.should_not == 'foo $0 bar'
          err.should == ''
        end

        it %q<without the shell if given multiple arguments> do
          out, err = fig %w<-- echo foo $0 bar>
          out.should == 'foo $0 bar'
          err.should == ''
        end

        it %q<fails if no actual command specified> do
          out, err, exit_code = fig ['--'], :no_raise_on_error => true
          err.should =~ /no command.*specified/i
          out.should == ''
          exit_code.should_not == 0
        end
      end
    end
  end
end
