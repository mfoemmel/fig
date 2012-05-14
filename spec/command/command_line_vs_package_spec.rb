require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  describe 'command-line options vs package files' do
    it %q<gives a "set" statement priority over a "--set" option> do
      input = <<-END
        config default
          set TEST=package.fig
        end
      END
      fig('--set TEST=command-line --get TEST', input)[0].should == 'command-line'
    end

    it %q<gives an "add" statement priority over a "--append" option> do
      input = <<-END
        config default
          add TEST_PATH=package.fig
        end
      END
      fig('--append TEST_PATH=command-line --get TEST_PATH', input)[0].should ==
        "command-line#{File::PATH_SEPARATOR}package.fig"
    end
  end
end
