require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'fig/os'
require 'fig/windows'


# Only run on Windows...
if Fig::OS.windows?
  describe "Fig on Windows" do
    it "batch script should exist" do
      Fig::Windows.with_generated_batch_script(["echo", "Hello World"]) do |filename|
        File.exist?(filename).should == true
      end
    end

    it "batch script should say 'Hello World' when executed" do
      Fig::Windows.with_generated_batch_script(["echo", "Hello World"]) do |filename|
        %x[#{filename}].should == "Hello World\n"
      end
    end
  end
end
