require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Fig' do
  describe 'environment variables' do
    before(:each) do
      setup_test_environment
    end

    it 'sets variable from command line' do
      fig('--set FOO=BAR --get FOO')[0].should == 'BAR'
      fig('--set FOO=BAR --get FOO')[0].should == 'BAR'
    end

    it 'sets variable from fig file' do
      input = <<-END
        config default
          set FOO=BAR
        end
      END
      fig('--get FOO', input)[0].should == 'BAR'
    end

    it 'appends variable from command line' do
      fig('--append PATH=foo --get PATH').should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}", '', 0]
    end

    it 'appends variable from fig file' do
      input = <<-END
        config default
          add PATH=foo
        end
      END
      fig('--get PATH', input).should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}", '', 0]
    end

    it 'appends empty variable' do
      fig('--append XYZZY=foo --get XYZZY').should == ['foo', '', 0]
    end

    it %q<doesn't expand variables without packages> do
      fig('--set FOO=@bar --get FOO')[0].should == '@bar'
    end
  end
end
