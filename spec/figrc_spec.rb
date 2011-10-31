require 'stringio'
require 'tempfile'

require 'fig/figrc'
require 'fig/retriever'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

setup_repository()

describe 'FigRC' do
  it 'parses an application configuration file(handle)' do
    configuration = Fig::FigRC.load_from_handle(
      StringIO.new(
        %q<
          { "foo": "bar" }
        >
      )
    )
    configuration['foo'].should == 'bar'
  end

  it 'handles override paths' do
    tempfile = Tempfile.new('some_json_tempfile')
    tempfile << %q< { "foo" : "bar" } >
    tempfile.close

    r = Retriever.new('does not exist')
    configuration = Fig::FigRC.find( r, tempfile.path )
    tempfile.delete

    configuration['foo'].should == 'bar'
  end

  it 'handles no repository config and no override specified' do
    configuration = Fig::FigRC.find(nil,nil)
    configuration.should_not == nil
  end
end
