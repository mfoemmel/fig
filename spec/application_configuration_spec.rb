require 'fig/application_configuration'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

REPOSITORY_TEST_URL = 'http://example.com'
WHITELIST_TEST_URL = 'http://foo.com'

describe 'ApplicationConfiguration' do
  it 'allows arbitrary urls when there is no whitelist' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.url_access_allowed?('').should == true
  end

  it 'allows the repo url when whitelist is empty' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => []})
    config.url_access_allowed?(REPOSITORY_TEST_URL).should == true
  end

  it 'disallows a non-repo url when whitelist is empty' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => []})
    config.url_access_allowed?('').should == false
  end

  it 'disallows a url that starts with a whitelisted url that is a hostname only' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => []})
    config.url_access_allowed?(REPOSITORY_TEST_URL + 'x').should == false
  end

  it 'allows a full url with empty whitelist' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => []})
    config.url_access_allowed?(REPOSITORY_TEST_URL + '/x').should == true
  end

  it 'allows a url when it\'s on the whitelist' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => [REPOSITORY_TEST_URL]})
    config.url_access_allowed?(REPOSITORY_TEST_URL + '/x').should == true
  end

  it 'disallows a url when it\'s not on the whitelist' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => [WHITELIST_TEST_URL]})
    config.url_access_allowed?('http://bar.com' + '/x').should == false
  end

  it 'disallows a non-repo url when whitelist is not empty' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => [WHITELIST_TEST_URL]})
    config.url_access_allowed?('').should == false
  end

  it 'disallows a url with a different port (but the first part matches)' do
    config = Fig::ApplicationConfiguration.new(REPOSITORY_TEST_URL)
    config.push_dataset({'url whitelist' => [WHITELIST_TEST_URL+':2000']})
    config.url_access_allowed?(WHITELIST_TEST_URL+':20001').should == false
  end
end
