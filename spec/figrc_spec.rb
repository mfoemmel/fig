require 'fileutils'
require 'stringio'
require 'tempfile'

require 'fig/figrc'
require 'fig/retriever'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

setup_repository()

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

def create_remote_config(foo, bar = nil)
    FileUtils.mkdir_p(File.join(FIG_REMOTE_DIR, '_meta'))
    figrc_path = File.join(FIG_REMOTE_DIR,'_meta/figrc')
    file_handle = File.new(figrc_path,'w')
    file_handle.write( %Q< { "foo" : "#{foo}" > )
    if not bar.nil?
      file_handle.write( %Q< , "bar" : "#{bar}" > )
    end
    file_handle.write( %Q< } > )
    file_handle.close
    return
end

describe 'FigRC' do
  it 'parses an application configuration file(handle)' do
    configuration = Fig::FigRC.load_from_handle(
      StringIO.new(
        %q<
          { "foo": "loaded from handle" }
        >
      )
    )
    configuration['foo'].should == 'loaded from handle'
  end

  it 'handles override path with a remote repository' do
    tempfile = create_override_file('loaded as override')

    create_remote_config("loaded from repository (shouldn't be)")
    configuration = Fig::FigRC.find( tempfile.path, ENV['FIG_REMOTE_URL'], true, ENV['FIG_HOME'] )
    tempfile.unlink
    FileUtils.rm_rf([FIG_HOME,FIG_REMOTE_DIR])

    configuration['foo'].should == 'loaded as override'
  end

  it 'handles no override, no repository (full stop)' do
    configuration = Fig::FigRC.find(nil, nil, true, ENV['FIG_HOME'])
    configuration['foo'].should == nil
  end

  it 'handles no repository config and no override specified, and config does NOT exist on server' do
    configuration = Fig::FigRC.find(nil, %Q<ssh://#{ENV['USER']}@localhost/does_not_exist/>, true, ENV['FIG_HOME'])
    configuration['foo'].should == nil
  end

  it 'retrieves configuration from repository with no override' do
    create_remote_config('loaded from repository')

    configuration = Fig::FigRC.find(nil, ENV['FIG_REMOTE_URL'], true, ENV['FIG_HOME'])
    configuration['foo'].should == 'loaded from repository'
    FileUtils.rm_rf([FIG_HOME,FIG_REMOTE_DIR])
  end

  it 'has a remote config but gets its config from the override file provided' do
    create_remote_config('loaded from remote repository')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = Fig::FigRC.find(tempfile.path, ENV['FIG_REMOTE_URL'], true, ENV['FIG_HOME'])
    configuration['foo'].should == 'loaded as override to override remote config'
    FileUtils.rm_rf([FIG_HOME,FIG_REMOTE_DIR])
  end

  it 'merges override file config over remote config' do
    create_remote_config('loaded from remote repository','should not be overwritten')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = Fig::FigRC.find(tempfile.path, ENV['FIG_REMOTE_URL'], true, ENV['FIG_HOME'])
    configuration['foo'].should == 'loaded as override to override remote config'
    configuration['bar'].should == 'should not be overwritten'
    FileUtils.rm_rf([FIG_HOME,FIG_REMOTE_DIR])
  end
end
