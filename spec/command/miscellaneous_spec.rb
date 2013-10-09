require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/command/package_loader'

describe 'Fig' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it 'ignores comments' do
    input = <<-END
      # Some comment
      config default
        set FOO=BAR # Another comment
      end
    END
    fig(%w<--get FOO>, input)[0].should == 'BAR'
  end

  describe '--file' do
    it 'reads from the value' do
      dot_fig_file = "#{FIG_SPEC_BASE_DIRECTORY}/file-option-test.fig"
      write_file(dot_fig_file, <<-END)
        config default
          set FOO=BAR
        end
      END
      fig(['--file', dot_fig_file, '--get', 'FOO'])[0].should == 'BAR'
    end

    it 'complains about the value not existing' do
      out, err, exit_code =
        fig(%w<--file does-not-exist --get FOO>, :no_raise_on_error => true)
      out.should == ''
      err.should =~ /does-not-exist/
      exit_code.should_not == 0
    end
  end

  [
    Fig::Command::PackageLoader::DEFAULT_PACKAGE_FILE,
    Fig::Command::PackageLoader::DEFAULT_APPLICATION_FILE,
  ].each do
    |file_name|

    it "ignores #{file_name} with the --no-file option" do
      dot_fig_file = "#{FIG_SPEC_BASE_DIRECTORY}/#{file_name}"
      write_file(dot_fig_file, <<-END)
        config default
          set FOO=BAR
        end
      END
      fig(%w<--no-file --get FOO>)[0].should == ''
    end
  end

  it 'complains about conflicting package versions' do
    fig(%w<--publish foo/1.2.3 --set VARIABLE=VALUE>)
    fig(%w<--publish foo/4.5.6 --set VARIABLE=VALUE>)

    out, err, exit_code = fig(
      %w<--update --include foo/1.2.3 --include foo/4.5.6>,
      :no_raise_on_error => true
    )
    exit_code.should_not == 0
    err.should =~ /version mismatch for package foo/i
  end

  describe 'emits the version number' do
    %w/-v --version/.each do
      |option|

      it "descriptively with #{option}" do
        (out, err, exitstatus) = fig([option])
        exitstatus.should == 0
        err.should == ''
        out.should =~ %r<
          \A                # Start of string
          \w+               # Some text...
          \s+               # ... followed by some whitespace
          .*                # whatever (so test doesn't change as the text does)
          \d+ \. \d+ \. \d+ # Some dotted number
        >x
      end
    end

    it 'plainly with --version-plain' do
      (out, err, exitstatus) =
        fig %w< --version-plain >, :dont_strip_output => true

      exitstatus.should == 0
      err.should == ''
      out.should =~ %r<
        \A                # Start of string
        \d+ \. \d+ \. \d+ # Some dotted number
      >x
      out.should_not =~ %r< \n \z >x
    end
  end

  describe 'emits help summary for' do
    %w/-? -h --help/.each do
      |option|

      it option do
        out, err = fig([option])
        err.should == ''
        out.should =~ / \b summary \b   /xi
        out.should =~ / \b fig \b       /x
        out.should =~ / --update \b     /x
        out.should =~ / --set \b        /x
        out.should =~ / --publish \b    /x
        out.should =~ / --options \b    /x
        out.should =~ / --help-long \b  /x
      end
    end
  end

  it 'emits full help with --help-long' do
    out, err = fig(['--help-long'])
    err.should == ''
    out.should =~ / \b fig \b             /x
    out.should =~ / --update \b           /x
    out.should =~ / --set \b              /x
    out.should =~ / --publish \b          /x
    out.should =~ / --force \b            /x
    out.should =~ / --help \b             /x
    out.should =~ / --help-long \b        /x
    out.should =~ / --options \b          /x
    out.should =~ / \b FIG_REMOTE_URL \b  /x
    out.should =~ / \b FIG_HOME \b        /x
  end

  it 'emits option list with --options' do
    out, err = fig(['--options'])
    err.should == ''
    out.should =~ / options:      /ix
    out.should =~ / --help \b     /x
    out.should =~ / --options \b  /x
  end
end
