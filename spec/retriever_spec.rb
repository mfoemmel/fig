require 'fig/retriever'

describe 'Retriever' do
  it 'retrieves single file' do

    # Set up some test files
    test_dir = 'tmp/retrieve-test'
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir_p(test_dir)

    File.open('tmp/foo.txt', 'w') {|f| f << 'FOO'}
    File.open('tmp/bar.txt', 'w') {|f| f << 'BAR'}
    File.open('tmp/baz.txt', 'w') {|f| f << 'BAZ'}

    # Retrieve files A and B
    r = Retriever.new(test_dir)
    r.with_config('foo', '1.2.3') do
      r.retrieve('tmp/foo.txt', 'foo.txt')
      r.retrieve('tmp/bar.txt', 'bar.txt')
      File.read(File.join(test_dir, 'foo.txt')).should == 'FOO'
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
    end

    # Retrieve files B and C for a different version
    r.with_config('foo', '4.5.6') do
      r.retrieve('tmp/bar.txt', 'bar.txt')
      r.retrieve('tmp/baz.txt', 'baz.txt')
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
      File.read(File.join(test_dir, 'baz.txt')).should == 'BAZ'
      File.exist?(File.join(test_dir, 'foo.txt')).should == false
    end

    # Save and reload
    r.save
    r = Retriever.new(test_dir)

    # Switch back to original version
    r.with_config('foo', '1.2.3') do
      r.retrieve('tmp/foo.txt', 'foo.txt')
      r.retrieve('tmp/bar.txt', 'bar.txt')

      File.read(File.join(test_dir, 'foo.txt')).should == 'FOO'
      File.read(File.join(test_dir, 'bar.txt')).should == 'BAR'
      File.exist?(File.join(test_dir, 'baz.txt')).should == false
    end
  end

  it 'preserves executable bit' do
    test_dir = 'tmp/retrieve-test'
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir_p(test_dir)

    File.open('tmp/plain', 'w') {|f| f << 'plain'}
    File.open('tmp/executable', 'w') {|f| f << 'executable'}
    FileUtils.chmod(0755, 'tmp/executable')

    r = Retriever.new(test_dir)
    r.with_config('foo', '1.2.3') do
      r.retrieve('tmp/plain', 'plain')
      r.retrieve('tmp/executable', 'executable')

      File.stat(File.join(test_dir, 'plain')).executable?.should == false
      File.stat(File.join(test_dir, 'executable')).executable?.should == true
    end
  end
end
