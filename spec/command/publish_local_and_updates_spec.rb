# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Fig' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it %q<doesn't remove --publish-local packages during a failed --update.> do
    fig %w<--publish-local publish-local/test --set foo=bar>

    out, err, exit_code = fig(
      %w<publish-local/test --get foo>, :fork => false
    )
    out.should == 'bar'

    # Should not work because we didn't send it to the remote repo.
    out, err, exit_code = fig(
      %w<publish-local/test --update --get foo>,
      :no_raise_on_error => true
    )
    exit_code.should_not == 0

    # Should still work
    out, err, exit_code = fig(
      %w<publish-local/test --get foo>, :fork => false
    )
    out.should == 'bar'
  end
end
