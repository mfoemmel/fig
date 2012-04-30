require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/workingdirectorymaintainer'

describe 'WorkingDirectoryMaintainer' do
  let(:base_directory)    { "#{FIG_SPEC_BASE_DIRECTORY}/retrieve-test" }
  let(:working_directory) { "#{base_directory}/working" }
  let(:source_directory)  { "#{base_directory}/source" }

  before(:all) do
    setup_test_environment
  end

  before(:each) do
    [working_directory, source_directory].each do
      |directory|

      FileUtils.rm_rf(directory)
      FileUtils.mkdir_p(directory)
    end
  end

  it 'maintains files for a single package' do
    # Set up some test files
    source_foo = "#{source_directory}/foo.txt"
    source_bar = "#{source_directory}/bar.txt"
    source_baz = "#{source_directory}/baz.txt"
    File.open(source_foo, 'w') {|f| f << 'FOO'}
    File.open(source_bar, 'w') {|f| f << 'BAR'}
    File.open(source_baz, 'w') {|f| f << 'BAZ'}

    working_foo = File.join(working_directory, 'foo.txt')
    working_bar = File.join(working_directory, 'bar.txt')
    working_baz = File.join(working_directory, 'baz.txt')

    # Retrieve files A and B
    r = Fig::WorkingDirectoryMaintainer.new(working_directory)
    r.with_package_version('foo', '1.2.3') do
      r.retrieve(source_foo, 'foo.txt')
      r.retrieve(source_bar, 'bar.txt')
      File.read(working_foo).should == 'FOO'
      File.read(working_bar).should == 'BAR'
    end

    # Retrieve files B and C for a different version
    r.with_package_version('foo', '4.5.6') do
      r.retrieve(source_bar, 'bar.txt')
      r.retrieve(source_baz, 'baz.txt')
      File.read(working_bar).should == 'BAR'
      File.read(working_baz).should == 'BAZ'
      File.exist?(working_foo).should == false
    end

    # Save and reload
    r.save_metadata()
    r = Fig::WorkingDirectoryMaintainer.new(working_directory)

    # Switch back to original version
    r.with_package_version('foo', '1.2.3') do
      r.retrieve(source_foo, 'foo.txt')
      r.retrieve(source_bar, 'bar.txt')

      File.read(working_foo).should == 'FOO'
      File.read(working_bar).should == 'BAR'
      File.exist?(working_baz).should == false
    end
  end

  it 'preserves executable bit' do
    File.open("#{source_directory}/plain", 'w') {|f| f << 'plain'}
    File.open("#{source_directory}/executable", 'w') {|f| f << 'executable.exe'}
    FileUtils.chmod(0755, "#{source_directory}/executable")

    r = Fig::WorkingDirectoryMaintainer.new(working_directory)
    r.with_package_version('foo', '1.2.3') do
      r.retrieve("#{source_directory}/plain", 'plain')
      r.retrieve("#{source_directory}/executable", 'executable.exe')

      File.stat(File.join(working_directory, 'plain')).executable?.should == false
      File.stat(File.join(working_directory, 'executable.exe')).executable?.should == true
    end
  end
end
