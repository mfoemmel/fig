require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/working_directory_maintainer'

describe 'WorkingDirectoryMaintainer' do
  let(:base_directory)    { "#{FIG_SPEC_BASE_DIRECTORY}/retrieve-test" }
  let(:working_directory) { "#{base_directory}/working" }
  let(:source_directory)  { "#{base_directory}/source" }

  before(:each) do
    clean_up_test_environment
    set_up_test_environment

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
    maintainer = Fig::WorkingDirectoryMaintainer.new(working_directory)
    maintainer.switch_to_package_version('foo', '1.2.3')
    maintainer.retrieve(source_foo, 'foo.txt')
    maintainer.retrieve(source_bar, 'bar.txt')
    File.read(working_foo).should == 'FOO'
    File.read(working_bar).should == 'BAR'

    # Retrieve files B and C for a different version
    maintainer.switch_to_package_version('foo', '4.5.6')
    maintainer.retrieve(source_bar, 'bar.txt')
    maintainer.retrieve(source_baz, 'baz.txt')
    File.read(working_bar).should == 'BAR'
    File.read(working_baz).should == 'BAZ'
    File.exist?(working_foo).should == false

    # Save and reload
    maintainer.prepare_for_shutdown(:purged_unused_packages)
    maintainer = Fig::WorkingDirectoryMaintainer.new(working_directory)

    # Switch back to original version
    maintainer.switch_to_package_version('foo', '1.2.3')
    maintainer.retrieve(source_foo, 'foo.txt')
    maintainer.retrieve(source_bar, 'bar.txt')

    File.read(working_foo).should == 'FOO'
    File.read(working_bar).should == 'BAR'
    File.exist?(working_baz).should == false
  end

  it 'preserves executable bit' do
    File.open("#{source_directory}/plain", 'w') {|f| f << 'plain'}
    File.open("#{source_directory}/executable", 'w') {|f| f << 'executable.exe'}
    FileUtils.chmod(0755, "#{source_directory}/executable")

    maintainer = Fig::WorkingDirectoryMaintainer.new(working_directory)
    maintainer.switch_to_package_version('foo', '1.2.3')
    maintainer.retrieve("#{source_directory}/plain", 'plain')
    maintainer.retrieve("#{source_directory}/executable", 'executable.exe')

    File.stat(File.join(working_directory, 'plain')).executable?.should == false
    File.stat(File.join(working_directory, 'executable.exe')).executable?.should == true
  end

  it 'fails on corrupted metadata' do
    FileUtils.mkdir_p("#{working_directory}/.fig")

    metadata_file = "#{working_directory}/.fig/retrieve"
    write_file(metadata_file, 'random garbage')

    expect {
      Fig::WorkingDirectoryMaintainer.new(working_directory)
    }.to raise_error(/parse error/)

    # This is so much fun.  It appears that once we've had a file open within
    # this process, we cannot delete that file, i.e. "File.rm(metadata_file)"
    # results in an EACCESS on Windows.  So, in lieu of removing the file, we
    # just make it empty.
    write_file(metadata_file, '')
  end
end
