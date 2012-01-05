require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'English'

require 'fig/os'

setup_repository

def set_up_local_and_remote_repository
  cleanup_home_and_remote

  input = <<-END
    config default
      set FOO=BAR
    end
  END

  fig('--publish remote-only/1.2.3', input)
  fig('--clean remote-only/1.2.3', input)
  fig('--publish both/1.2.3', input)
  fig('--publish-local local-only/1.2.3', input)

  return
end

describe 'Fig' do
  describe '--list-local' do
    it %q<prints nothing with an empty repository> do
      cleanup_home_and_remote

      (out, err, exitstatus) = fig('--list-local')
      exitstatus.should == 0
      out.should == ''
      err.should == ''
    end

    it %q<prints only local packages> do
      set_up_local_and_remote_repository

      (out, err, exitstatus) = fig('--list-local')
      exitstatus.should == 0
      out.should == "both/1.2.3\nlocal-only/1.2.3"
      err.should == ''
    end
  end

  describe '--list-remote' do
    it %q<prints nothing with an empty repository> do
      cleanup_home_and_remote

      (out, err, exitstatus) = fig('--list-remote')
      exitstatus.should == 0
      out.should == ''
      err.should == ''
    end

    it %q<prints only remote packages> do
      set_up_local_and_remote_repository

      (out, err, exitstatus) = fig('--list-remote')
      exitstatus.should == 0
      out.should == "both/1.2.3\nremote-only/1.2.3"
      err.should == ''
    end
  end
end
