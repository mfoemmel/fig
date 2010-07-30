require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'rubygems'
require 'fig/os'
require 'fileutils'

class Popen
  if Fig::OS.windows?
    require 'win32/open3'
    def self.popen(*cmd)
      Open3.popen3(*cmd) { |stdin,stdout,stderr|
        yield stdin, stdout, stderr
      }
    end
  else
    require 'open4'
    def self.popen(*cmd)
      Open4::popen4(*cmd) { |pid, stdin, stdout, stderr|
        yield stdin, stdout, stderr
      }
    end
  end
end

FIG_HOME = File.expand_path(File.dirname(__FILE__) + '/../tmp/fighome')
FileUtils.mkdir_p(FIG_HOME)
ENV['FIG_HOME'] = FIG_HOME

FIG_REMOTE_DIR = File.expand_path(File.dirname(__FILE__) + '/../tmp/remote')
FileUtils.mkdir_p(FIG_REMOTE_DIR)
ENV['FIG_REMOTE_URL'] = "ssh://#{ENV['USER']}@localhost#{FIG_REMOTE_DIR}"

FIG_EXE = File.expand_path(File.dirname(__FILE__) + '/../bin/fig')

def fig(args, input=nil)
  args = "--file - #{args}" if input
  out = nil
  err = nil
  Popen.popen("#{FIG_EXE} #{args}") do |stdin, stdout, stderr|
    if input
      stdin.puts input
      stdin.close
    end
    err = stderr.read.strip
    out = stdout.read.strip
    if err != ""
      $stderr.puts err
    end
  end
  return out, err, $?.exitstatus
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
    fig('-g FOO', input)[0].should == 'BAR'
  end

  it "append environment variable from command line" do
    fig('-p PATH=foo -g PATH').should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}","",0]
  end

  it "append environment variable from fig file" do
    input = <<-END
      config default
        add PATH=foo
      end
    END
    fig('-g PATH', input).should == ["foo#{File::PATH_SEPARATOR}#{ENV['PATH']}","",0]
  end

  it "append empty environment variable" do
    fig('-p XYZZY=foo -g XYZZY').should == ["foo","",0]
  end

  it "should ignore comments" do
    input = <<-END
      #/usr/bin/env fig

      # Some comment
      config default
        set FOO=BAR # Another comment
      end
    END
    fig('-g FOO', input)[0].should == 'BAR'
  end

  it "publish to remote repository" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    input = <<-END
      config default
        set FOO=BAR
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + "/repos/foo/1.2.3/.fig"
    fail unless File.exists? FIG_REMOTE_DIR + "/foo/1.2.3/.fig"
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'BAR'
  end

  it "publish resource to remote repository" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    FileUtils.mkdir_p("tmp/bin")
    File.open("tmp/bin/hello", "w") { |f| f << "echo bar" }
    fail unless system "chmod +x tmp/bin/hello"
    input = <<-END
      resource tmp/bin/hello
      config default
        append PATH=@/tmp/bin
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + "/repos/foo/1.2.3/.fig"
    fail unless File.exists? FIG_REMOTE_DIR + "/foo/1.2.3/.fig"
    fig('-u -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it "publish resource to remote repository using command line" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    FileUtils.mkdir_p("tmp/bin")
    File.open("tmp/bin/hello", "w") { |f| f << "echo bar" }
    fail unless system "chmod +x tmp/bin/hello"
    fig('--publish foo/1.2.3 --resource tmp/bin/hello --append PATH=@/tmp/bin')
    fail unless File.exists? FIG_HOME + "/repos/foo/1.2.3/.fig"
    fail unless File.exists? FIG_REMOTE_DIR + "/foo/1.2.3/.fig"
    fig('-u -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it "refuses to overwrite existing version in remote repository without being forced" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    input = <<-END
      config default
        set FOO=SHEEP
      end
    END
    fig('--publish foo/1.2.3', input)
    fail unless File.exists? FIG_HOME + "/repos/foo/1.2.3/.fig"
    fail unless File.exists? FIG_REMOTE_DIR + "/foo/1.2.3/.fig"
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'SHEEP'

    input = <<-END
      config default
        set FOO=CHEESE
      end
    END
    (out, err, exitstatus) = fig('--publish foo/1.2.3', input)
    exitstatus.should == 1
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'SHEEP'

    (out, err, exitstatus) = fig('--publish foo/1.2.3 --force', input)
    exitstatus.should == 0
    fig('-u -i foo/1.2.3 -g FOO')[0].should == 'CHEESE'
  end

  it "publishes to the local repo only when told to" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    FileUtils.mkdir_p("tmp/bin")
    File.open("tmp/bin/hello", "w") { |f| f << "echo bar" }
    fail unless system "chmod +x tmp/bin/hello"
    fig('--publish-local foo/1.2.3 --resource tmp/bin/hello --append PATH=@/tmp/bin')
    fail if File.exists? FIG_REMOTE_DIR + "/foo/1.2.3/.fig"
    fail unless fig('-m -i foo/1.2.3 -- hello')[0].should == 'bar'
  end

  it "retrieve resource" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    FileUtils.rm_rf("tmp")
    FileUtils.mkdir_p("tmp/lib")
    File.open("tmp/lib/hello", "w") { |f| f << "some library" }
    input = <<-END
      resource tmp/lib/hello
      config default
        append FOOPATH=@/tmp/lib/hello
      end
    END
    fig('--publish foo/1.2.3', input)
    input = <<-END
      retrieve FOOPATH->tmp/lib2/[package]
      config default
        include foo/1.2.3
      end
    END
    fig('-m', input)
    File.read("tmp/lib2/foo/hello").should == "some library"
  end

  it "package multiple resources" do
    FileUtils.rm_rf(FIG_HOME)
    FileUtils.rm_rf(FIG_REMOTE_DIR)
    FileUtils.rm_rf("tmp")
    FileUtils.mkdir_p("tmp/lib")
    File.open("tmp/lib/hello", "w") { |f| f << "some library" }
    File.open("tmp/lib/hello2", "w") { |f| f << "some other library" }
    input = <<-END
      resource tmp/lib/hello
      resource tmp/lib/hello2
      config default
        append FOOPATH=@/tmp/lib/hello
        append FOOPATH=@/tmp/lib/hello2
      end
    END
    fig('--publish foo/1.2.3', input)
    input = <<-END
      retrieve FOOPATH->tmp/lib2/[package]
      config default
        include foo/1.2.3
      end
    END
    fig('-m', input)
    File.read("tmp/lib2/foo/hello").should == "some library"
    File.read("tmp/lib2/foo/hello2").should == "some other library"
  end
end
