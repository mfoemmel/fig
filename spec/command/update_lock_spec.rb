require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/update_lock'

describe 'Fig' do
  describe '--update-lock-response' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment

      # Note that this could cause RSpec to block forever if we've got a bug,
      # but it's necessary in order to test.
      @update_lock = Fig::UpdateLock.new(FIG_HOME, :wait)
    end

    after(:each) do
      # Shouldn't be necessary, but let's be paranoid.
      @update_lock.close
      @update_lock = nil
    end

    it 'ignore' do
      out, err, exit_code =
        fig('--update --update-lock-response ignore --set FOO=BAR --get FOO')

      out.should == 'BAR'
      exit_code.should == 0
    end

    it 'fail' do
      out, err, exit_code =
        fig(
          '--update --update-lock-response fail --set FOO=BAR --get FOO',
          :no_raise_on_error => true
        )

      err.should =~
        /cannot update while another instance of Fig is updating/i
      exit_code.should_not == 0
    end
  end
end
