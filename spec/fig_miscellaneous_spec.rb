require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Fig' do
  before(:each) do
    cleanup_test_environment
    setup_test_environment
  end

  it 'ignores comments' do
    input = <<-END
      # Some comment
      config default
        set FOO=BAR # Another comment
      end
    END
    fig('--get FOO', input)[0].should == 'BAR'
  end

  it 'reads from the value of --file' do
    dot_fig_file = "#{FIG_SPEC_BASE_DIRECTORY}/file-option-test.fig"
    write_file(dot_fig_file, <<-END)
      config default
        set FOO=BAR
      end
    END
    fig("--file #{dot_fig_file} --get FOO")[0].should == 'BAR'
  end

  it 'prints the version number' do
    %w/-v --version/.each do |option|
      (out, err, exitstatus) = fig(option)
      exitstatus.should == 0
      err.should == ''
      out.should =~ / \d+ \. \d+ \. \d+ /x
    end
  end

  it 'emits help' do
    %w/-? -h --help/.each do |option|
      (out, err, exitstatus) = fig(option)
      exitstatus.should == 0
      err.should == ''
      out.should =~ / Usage: /x
      out.should =~ / \b fig \b /x
      out.should =~ / --help \b /x
      out.should =~ / --force \b /x
      out.should =~ / --update \b /x
      out.should =~ / --set \b /x
    end
  end
end
