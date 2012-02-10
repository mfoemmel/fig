require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/applicationconfiguration'
require 'fig/packagedescriptor'
require 'fig/packageparseerror'
require 'fig/parser'

describe 'Parser' do
  it 'passes valid, whitelisted urls' do
    fig_package=<<-FIG_PACKAGE
      resource http://example/is/awesome.tgz

      archive http://svpsvn/my/repo/is/cool.jar
    FIG_PACKAGE
    application_configuration = Fig::ApplicationConfiguration.new('http://example/')
    application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

    package = Fig::Parser.new(application_configuration).parse_package(
      Fig::PackageDescriptor.new('package_name', 'version', nil),
      'foo_directory',
      fig_package
    )
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
      package = Fig::Parser.new(application_configuration).parse_package(
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
        'foo_directory',
        fig_package
      )
    rescue Fig::URLAccessError => exception
    end
    exception.should_not == nil
    exception.urls.should =~ %w<http://evil_url/is/bad.tgz http://evil_repo/my/repo/is/bad.jar>
    exception.descriptor.name.should == 'package_name'
    exception.descriptor.version.should == '0.1.1'
  end

  it 'rejects multiple commands in config file' do
    fig_package=<<-END
      config default
        command "echo foo"
        command "echo bar"
      end
    END

    application_configuration =
      Fig::ApplicationConfiguration.new('http://example/')

    expect {
      Fig::Parser.new(application_configuration).parse_package(
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
        'foo_directory',
        fig_package
      )
    }.to raise_error(
      Fig::UserInputError
    )
  end

  it 'accepts multiple configs, each with a single command' do
    fig_package=<<-END
      config default
        command "echo foo"
      end
      config another
        command "echo bar"
      end
    END

    application_configuration = Fig::ApplicationConfiguration.new('http://example/')
    Fig::Parser.new(application_configuration).parse_package(
      Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
      'foo_directory',
      fig_package
    )
    # Got no exception.
  end

  it 'rejects multiple configs where one has multiple commands' do
    fig_package=<<-END
      config default
        command "echo foo"
      end
      config another
        command "echo bar"
        command "echo baz"
      end
    END

    application_configuration = Fig::ApplicationConfiguration.new('http://example/')

    expect {
      Fig::Parser.new(application_configuration).parse_package(
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
        'foo_directory',
        fig_package
      )
    }.to raise_error(
      Fig::UserInputError
    )
  end

  it 'throws the correct exception on syntax error' do
    fig_package=<<-END
      this is invalid syntax
    END

    application_configuration = Fig::ApplicationConfiguration.new('http://example/')

    expect {
      Fig::Parser.new(application_configuration).parse_package(
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
        'foo_directory',
        fig_package
      )
    }.to raise_error(
      Fig::PackageParseError
    )
  end

  it 'Assigns the correct line and column number to Statement objects.' do
    fig_package=<<-FIG_PACKAGE

      # Blank line above to ensure that we can handle starting whitespace.
      resource http://example/is/awesome.tgz

          # Indentation in here is weird to test we get things right.

          # Also, we need a comment in here to make sure that cleaning them out
          # does not affect values for statements.

       archive http://svpsvn/my/repo/is/cool.jar

      config default
              include package/some-version

         set VARIABLE=VALUE
                end
    FIG_PACKAGE

    application_configuration = Fig::ApplicationConfiguration.new(nil)
    package = Fig::Parser.new(application_configuration).parse_package(
      Fig::PackageDescriptor.new('package_name', 'version', nil),
      'foo_directory',
      fig_package
    )

    package.walk_statements do
      |statement|

      case statement
        when Fig::Statement::Resource
          statement.line.should == 3
          statement.column.should == 7
        when Fig::Statement::Archive
          statement.line.should == 10
          statement.column.should == 8
        when Fig::Statement::Configuration
          statement.line.should == 12
          statement.column.should == 7
        when Fig::Statement::Include
          statement.line.should == 13
          statement.column.should == 15
        when Fig::Statement::Set
          statement.line.should == 15
          statement.column.should == 10
      end
    end
  end
end
