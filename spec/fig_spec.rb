require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'open3'
require 'fileutils'

FIG_HOME = File.expand_path(File.dirname(__FILE__) + '/../tmp/fighome')
FileUtils.mkdir_p(FIG_HOME)
ENV['FIG_HOME'] = FIG_HOME

FIG_REMOTE_DIR = File.expand_path(File.dirname(__FILE__) + '/../tmp/remote')
FileUtils.mkdir_p(FIG_REMOTE_DIR)
ENV['FIG_REMOTE_URL'] = "ssh://localhost#{FIG_REMOTE_DIR}"
puts ENV['FIG_REMOTE_URL']

def fig(args, input=nil)
  stdin, stdout, stderr = Open3.popen3("fig #{args}")
  if input
    stdin.puts input
    stdin.close
  end
  return stdout.read.strip, stderr.read.strip
end

describe "Fig" do
  it "set environment variable from command line" do
    fig('-s FOO=BAR -g FOO')[0].should == 'BAR'
    fig('--set FOO=BAR -g FOO')[0].should == 'BAR'
  end

  it "set environment variable from fig file" do
    input = <<-END
      config default
        set FOO=BAR
      end
    END
    fig('--input - -g FOO', input)[0].should == 'BAR'
  end

  it "append environment variable from command line" do
    fig('-p PATH=foo -g PATH').should == ["#{ENV['PATH']}#{File::PATH_SEPARATOR}foo",""]
  end

  it "append environment variable from fig file" do
    input = <<-END
      config default
        append PATH=foo
      end
    END
    fig('--input - -g PATH', input).should == ["#{ENV['PATH']}#{File::PATH_SEPARATOR}foo",""]
  end

  it "append empty environment variable" do
    fig('-p XYZZY=foo -g XYZZY').should == ["foo",""]
  end

  it "publish to remote repository" do
    input = <<-END
      publish
        config default
          set FOO=BAR
        end
      end
    END
    puts fig('--input - --publish foo/1.2.3', input)
    fig('-i foo/1.2.3 -g FOO').should == ['BAR','']
  end
end
