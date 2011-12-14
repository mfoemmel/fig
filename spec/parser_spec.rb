require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/applicationconfiguration'
require 'fig/parser'


describe 'Parser' do
  it 'passes valid, whitelisted urls' do
    fig_package=<<-FIG_PACKAGE
      resource http://example/is/awesome.tgz

      archive http://svpsvn/my/repo/is/cool.jar
    FIG_PACKAGE
    application_configuration = Fig::ApplicationConfiguration.new('http://example/')
    application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

    package = Fig::Parser.new(application_configuration).parse_package('package_name', 'version', 'foo_directory', fig_package)
    package.should_not == nil
  end

  it 'rejects non-whitelisted urls' do
    fig_package=<<-FIG_PACKAGE
      resource http://evil_url/is/bad.tgz

      archive http://evil_repo/my/repo/is/bad.jar
    FIG_PACKAGE
    application_configuration = Fig::ApplicationConfiguration.new('http://example/')
    application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

    exception = nil
    begin
      package = Fig::Parser.new(application_configuration).parse_package('package_name', '0.1.1', 'foo_directory', fig_package)
    rescue Fig::URLAccessError => exception
    end
    exception.should_not == nil
    exception.urls.should =~ %w<http://evil_url/is/bad.tgz http://evil_repo/my/repo/is/bad.jar>
    exception.package.should == 'package_name'
    exception.version.should == '0.1.1'
  end

  it 'rejects multiple commands in config file' do
    fig_package=<<-END
      config default
        command "echo foo"
        command "echo foo"
      end
    END

    application_configuration =
      Fig::ApplicationConfiguration.new('http://example/')

    expect {
      Fig::Parser.new(application_configuration).parse_package(
        'package_name', '0.1.1', 'foo_directory', fig_package
      )
    }.to raise_error(
      Fig::UserInputError
    )
  end
end
