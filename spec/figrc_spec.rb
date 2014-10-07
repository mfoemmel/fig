require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'
require 'tempfile'

require 'fig/figrc'
require 'fig/operating_system'
require 'fig/repository'
require 'fig/working_directory_maintainer'

describe 'FigRC' do
  def create_override_file(foo, bar = nil)
    tempfile = Tempfile.new('some_json_tempfile')
    tempfile << %Q< { "foo" : "#{foo}" >
    if not bar.nil?
      tempfile << %Q< , "bar" : "#{bar}" >
    end
    tempfile << %Q< } >
    tempfile.close
    return tempfile
  end

  def create_override_file_with_repository_url()
    tempfile = Tempfile.new('some_json_tempfile')
    tempfile << %Q< { "default FIG_REMOTE_URL" : "#{FIG_REMOTE_URL}" } >
    tempfile.close
    return tempfile
  end

  def create_remote_config(foo, bar = nil)
    FileUtils.mkdir_p(
      File.join(FIG_REMOTE_DIR, Fig::Repository::METADATA_SUBDIRECTORY)
    )
    figrc_path = File.join(FIG_REMOTE_DIR, Fig::FigRC::REPOSITORY_CONFIGURATION)
    file_handle = File.new(figrc_path,'w')
    file_handle.write( %Q< { "foo" : "#{foo}" > )
    if not bar.nil?
      file_handle.write( %Q< , "bar" : "#{bar}" > )
    end
    file_handle.write( %Q< } > )
    file_handle.close
    return
  end

  def invoke_find(override_path, repository_url)
    return Fig::FigRC.find(
      override_path,
      repository_url,
      Fig::OperatingSystem.new(false),
      FIG_HOME,
      true
    )
  end

  before(:all) do
    set_up_test_environment
  end

  after(:each) do
    clean_up_test_environment
  end

  it 'handles override path with a remote repository' do
    tempfile = create_override_file('loaded as override')

    create_remote_config("loaded from repository (shouldn't be)")
    configuration = invoke_find tempfile.path, FIG_REMOTE_URL
    tempfile.unlink

    configuration['foo'].should == 'loaded as override'
  end

  it 'handles no override, no repository (full stop)' do
    configuration = invoke_find nil, nil
    configuration['foo'].should == nil
  end

  it 'handles no override, repository specified as the empty string' do
    configuration = invoke_find nil, ''
    configuration['foo'].should == nil
  end

  it 'handles no override, repository specified as whitespace' do
    configuration = invoke_find nil, " \n\t"
    configuration['foo'].should == nil
  end

  it 'handles no repository config and no override specified, and config does NOT exist on server' do
    configuration = invoke_find nil, 'file:///does_not_exist/'
    configuration['foo'].should == nil
  end

  it 'retrieves configuration from repository with no override' do
    create_remote_config('loaded from repository')

    configuration = invoke_find nil, FIG_REMOTE_URL
    configuration['foo'].should == 'loaded from repository'
  end

  it 'has a remote config but gets its config from the override file provided' do
    create_remote_config('loaded from remote repository')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = invoke_find tempfile.path, FIG_REMOTE_URL
    configuration['foo'].should == 'loaded as override to override remote config'
  end

  it 'merges override file config over remote config' do
    create_remote_config('loaded from remote repository', 'should not be overwritten')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = invoke_find tempfile.path, FIG_REMOTE_URL
    configuration['foo'].should == 'loaded as override to override remote config'
    configuration['bar'].should == 'should not be overwritten'
  end

  it 'retrieves configuration from repository specified by override file' do
    tempfile = create_override_file_with_repository_url
    create_remote_config('loaded from repository')

    configuration = invoke_find tempfile.path, nil
    configuration['foo'].should == 'loaded from repository'
  end
end
