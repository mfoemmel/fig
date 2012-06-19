require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'English'

require 'fig/command/package_loader'

describe 'Fig' do
  describe 'usage errors: fig' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<prints usage message when passed an unknown option> do
      out, err, exit_status = fig('--no-such-option', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ / --no-such-option /x
      err.should =~ / usage /xi
      out.should == ''
    end

    it %q<prints message when there's nothing to do and there's no package.fig file> do
      out, err, exit_status = fig('', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ /nothing to do/i
      out.should == ''
    end

    it %q<prints message when there's nothing to do and there's a package.fig file> do
      write_file(
        "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}",
        <<-END_PACKAGE_DOT_FIG
          config default
          end
        END_PACKAGE_DOT_FIG
      )

      out, err, exit_status = fig('', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ /nothing to do/i
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a package descriptor> do
      out, err, exit_status =
        fig('package/descriptor extra bits', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a version> do
      out, err, exit_status = fig('/version', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ /package name required/i
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a config> do
      out, err, exit_status = fig(':config', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ /package name required/i
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a package> do
      out, err, exit_status = fig('package', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ /version required/i
      out.should == ''
    end

    it %q<prints error when a descriptor and --file is specified> do
      out, err, exit_status = fig(
          'package/version:default --file some.fig',
          :no_raise_on_error => true
        )
      exit_status.should == 1
      err.should =~ /cannot specify both a package descriptor.*and the --file option/i
      out.should == ''
    end

    it %q<prints error when a descriptor contains a config and --config is specified> do
      out, err, exit_status = fig(
          'package/version:default --config nondefault',
          :no_raise_on_error => true
        )
      exit_status.should == 1
      err.should =~ /Cannot specify both --config and a config in the descriptor/
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a command> do
      out, err, exit_status =
        fig('extra bits -- echo foo', :no_raise_on_error => true)
      exit_status.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when multiple --list-* options are given> do
      out, err, exit_status =
        fig('--list-remote --list-variables', :no_raise_on_error => true)
      exit_status.should == 1
      out.should == ''

      err.should =~ /cannot specify/i
    end

    describe %q<prints error when unknown package is referenced> do
      it %q<without --update> do
        out, err, exit_status = fig(
          'no-such-package/version --get PATH', :no_raise_on_error => true
        )
        exit_status.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update> do
        out, err, exit_status = fig(
            'no-such-package/version --update --get PATH',
            :no_raise_on_error => true
          )
        exit_status.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update-if-missing> do
        out, err, exit_status = fig(
            'no-such-package/version --update-if-missing --get PATH',
            :no_raise_on_error => true
        )
        exit_status.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end
    end

    describe %q<prints error when referring to non-existent configuration> do
      it %q<from the command-line as the base package> do
        fig('--publish foo/1.2.3 --set FOO=BAR')
        out, err, exit_status = fig(
            'foo/1.2.3:non-existent-config --get FOO',
            :no_raise_on_error => true
          )
        exit_status.should_not == 0
        err.should =~ %r< non-existent-config >x
        out.should == ''
      end

      it %q<from the command-line as an included package> do
        fig('--publish foo/1.2.3 --set FOO=BAR')
        out, err, exit_status = fig(
          '--include foo/1.2.3:non-existent-config --get FOO',
          :no_raise_on_error => true
        )
        exit_status.should_not == 0
        err.should =~ %r< foo/1\.2\.3:non-existent-config >x
        out.should == ''
      end
    end

    it %q<prints error when --include is specified without a package version> do
      out, err, exit_status = fig(
          '--include package-without-version --get FOO',
          :no_raise_on_error => true
        )
      exit_status.should_not == 0
      err.should =~ %r< package-without-version >x
      err.should =~ %r<no version specified>i
      out.should == ''
    end

    it %q<prints error when --override is specified without a package version> do
      out, err, exit_status = fig(
          '--override package-without-version',
          :no_raise_on_error => true
        )
      exit_status.should_not == 0
      err.should =~ %r< package-without-version >x
      err.should =~ %r<version required>i
      out.should == ''
    end

    it %q<prints error when --override is specified with a package config> do
      out, err, exit_status = fig(
          '--override package/version:config-should-not-be-here',
          :no_raise_on_error => true
        )
      exit_status.should_not == 0
      err.should =~ %r< package/version:config-should-not-be-here >x
      err.should =~ %r<config forbidden>i
      out.should == ''
    end

    describe %q<refuses to publish> do
      TEST_KEYWORDS =
        %w<
          add      append    archive  command   end
          include  override  path     resource  retrieve  set
        >

      describe %q<a package named the keyword> do
        TEST_KEYWORDS.each do
          |name|

          it %Q<"#{name}"> do
            out, err, exit_status =
              fig(
                "--publish #{name}/version --set FOO=BAR",
                :no_raise_on_error => true
              )
            err.should =~ %r< \b #{name} \b >x
            err.should =~ %r< \b keyword \b >ix
            err.should =~ %r< \b package \b >ix
            exit_status.should_not == 0
            out.should == ''
          end
        end
      end

      describe %q<a package containing a config named the keyword> do
        TEST_KEYWORDS.each do
          |name|

          it %Q<"#{name}"> do
            input = <<-END
              config #{name}
                set FOO=BAR
              end
            END

            out, err, exit_status =
              fig(
                '--publish package/version', input, :no_raise_on_error => true
              )
            err.should =~ %r< \b #{name} \b >x
            err.should =~ %r< \b keyword \b >ix
            err.should =~ %r< \b config \b >ix
            exit_status.should_not == 0
            out.should == ''
          end
        end
      end

      %w< archive resource >.each do
        |asset_type|

        describe %Q<a package containing a #{asset_type} named the keyword> do
          TEST_KEYWORDS.each do
            |name|

            describe %Q<"#{name}"> do
              it 'in a statement in a package definition file' do
                input = <<-END
                  #{asset_type} #{name}
                  config default
                    set FOO=BAR
                  end
                END

                out, err, exit_status =
                  fig(
                    '--publish package/version', input, :no_raise_on_error => true
                  )
                err.should =~ %r< \b #{name} \b >x
                err.should =~ %r< \b keyword \b >ix
                err.should =~ %r< \b #{asset_type} \b >ix
                exit_status.should_not == 0
                out.should == ''
              end

              it 'as a command-line option' do
                out, err, exit_status =
                  fig(
                    "--publish package/version --#{asset_type} #{name}",
                    :no_raise_on_error => true
                  )
                err.should =~ %r< \b #{name} \b >x
                err.should =~ %r< \b keyword \b >ix
                err.should =~ %r< \b #{asset_type} \b >ix
                exit_status.should_not == 0
                out.should == ''
              end
            end
          end
        end
      end

      it %q<a package named "_meta"> do
        out, err, exit_status =
          fig(
            '--publish _meta/version --set FOO=BAR',
            :no_raise_on_error => true
          )
        err.should =~ %r< cannot .* _meta >x
        exit_status.should_not == 0
        out.should == ''
      end

      it %q<without a package name> do
        out, err, exit_status =
          fig('--publish --set FOO=BAR', :no_raise_on_error => true)
        exit_status.should_not == 0
        err.should =~ %r<specify a descriptor>i
        out.should == ''
      end

      it %q<without a version> do
        out, err, exit_status = fig(
          '--publish a-package --set FOO=BAR', :no_raise_on_error => true
        )
        exit_status.should_not == 0
        err.should =~ %r<version required>i
        out.should == ''
      end
    end

    it %q<complains about command-line substitution of unreferenced packages> do
      fig('--publish a-package/a-version --set FOO=BAR')
      out, err, exit_status =
        fig('-- echo @a-package', :no_raise_on_error => true)
      exit_status.should_not == 0
      err.should =~ %r<\ba-package\b.*has not been referenced>
      out.should == ''
    end

    %w< --archive --resource >.each do
      |option|

      it %Q<warns about #{option} when not publishing> do
        out, err = fig("--get some_variable #{option} some-asset")
        err.should =~ /#{option}/
        err.should =~ /\bsome-asset\b/
      end
    end

    it %q<prints error when FIG_REMOTE_URL is not defined> do
      begin
        ENV.delete('FIG_REMOTE_URL')

        out, err, exit_status =
          fig('--list-remote', :no_raise_on_error => true)

        err.should =~ %r<FIG_REMOTE_URL>
        out.should == ''
        exit_status.should_not == 0
      ensure
        ENV['FIG_REMOTE_URL'] = FIG_REMOTE_URL
      end
    end
  end
end
