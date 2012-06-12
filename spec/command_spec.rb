require 'fig/command'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

REPOSITORY_TEST_URL = 'http://example.com'
WHITELIST_TEST_URL = 'http://foo.com'

describe 'Command (in-process)' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it 'accepts publish listener and ensures that it is invoked' do
    command = Fig::Command.new

    listener = mock('publish listener')
    listener.should_receive(:published)

    command.add_publish_listener(listener)

    command.run_fig(
      %w<--publish package/version --log-level off --set VARIABLE=VALUE>
    )
  end
end
