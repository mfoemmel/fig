require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/workingdirectorymaintainer'

describe 'WorkingDirectoryMaintainer' do
  before(:all) do
    setup_test_environment
  end

  it 'retrieves single file' do
    # Set up some test files
    test_dir = "#{FIG_SPEC_BASE_DIRECTORY}/retrieve-test"
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir_p(test_dir)

    File.open("#{FIG_SPEC_BASE_DIRECTORY}/foo.txt", 'w') {|f| f << 'FOO'}
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/bar.txt", 'w') {|f| f << 'BAR'}
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/baz.txt", 'w') {|f| f << 'BAZ'}

    # Retrieve files A and B
    r = Fig::WorkingDirectoryMaintainer.new(test_dir)
    r.with_package_version('foo', '1.2.3') do
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/foo.txt", 'foo.txt')
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/bar.txt", 'bar.txt')
      File.read(File.join(test_dir, 'foo.txt')).should == 'FOO'
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
    end

    # Retrieve files B and C for a different version
    r.with_package_version('foo', '4.5.6') do
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/bar.txt", 'bar.txt')
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/baz.txt", 'baz.txt')
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
      File.read(File.join(test_dir, 'baz.txt')).should == 'BAZ'
      File.exist?(File.join(test_dir, 'foo.txt')).should == false
    end

    # Save and reload
    r.save_metadata()
    r = Fig::WorkingDirectoryMaintainer.new(test_dir)

    # Switch back to original version
    r.with_package_version('foo', '1.2.3') do
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/foo.txt", 'foo.txt')
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/bar.txt", 'bar.txt')

      File.read(File.join(test_dir, 'foo.txt')).should == 'FOO'
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
      File.exist?(File.join(test_dir, 'baz.txt')).should == false
    end
  end

  it 'preserves executable bit' do
    test_dir = "#{FIG_SPEC_BASE_DIRECTORY}/retrieve-test"
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir_p(test_dir)

    File.open("#{FIG_SPEC_BASE_DIRECTORY}/plain", 'w') {|f| f << 'plain'}
    File.open("#{FIG_SPEC_BASE_DIRECTORY}/executable", 'w') {|f| f << 'executable.exe'}
    FileUtils.chmod(0755, "#{FIG_SPEC_BASE_DIRECTORY}/executable")

    r = Fig::WorkingDirectoryMaintainer.new(test_dir)
    r.with_package_version('foo', '1.2.3') do
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/plain", 'plain')
      r.retrieve("#{FIG_SPEC_BASE_DIRECTORY}/executable", 'executable.exe')

      File.stat(File.join(test_dir, 'plain')).executable?.should == false
      File.stat(File.join(test_dir, 'executable.exe')).executable?.should == true
    end
  end
end
