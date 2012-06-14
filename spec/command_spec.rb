require 'fig/command'
require 'fig/package_descriptor'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Command (in-process, instead of external program)' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it 'accepts post set-up action and ensures that it is invoked' do
    command = Fig::Command.new

    action = mock('post set-up action')
    action.should_receive(:set_up_finished)

    command.add_post_set_up_action(action)

    command.run_fig(
      %w<--log-level off --set VARIABLE=VALUE --get VARIABLE>
    )
  end

  it 'accepts publish listener and ensures that it is invoked' do
    command = Fig::Command.new

    listener = mock('publish listener')
    listener.should_receive(:published).with(
      hash_including(
        :descriptor         => instance_of(Fig::PackageDescriptor),
        :time               => anything(),
        :login              => anything(),
        :host               => anything(),
        :local_destination  => anything(),
        :remote_destination => anything(),
        :local_only         => anything()
      )
    )

    command.add_publish_listener(listener)

    command.run_fig(
      %w<--publish package/version --log-level off --set VARIABLE=VALUE>
    )
  end
end
