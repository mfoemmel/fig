require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/application_configuration'
require 'fig/package_descriptor'
require 'fig/package_parse_error'
require 'fig/parser'

describe 'Parser' do
  def new_configuration
    application_configuration = Fig::ApplicationConfiguration.new

    application_configuration.base_whitelisted_url = 'http://example/'
    application_configuration.remote_repository_url = 'http://example/'

    return application_configuration
  end

  def test_no_parse_exception(fig_input)
    application_configuration = new_configuration
    package = Fig::Parser.new(application_configuration, false).parse_package(
      Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
      'foo_directory',
      'source description',
      fig_input
    )
    # Got no exception.

    return package
  end

  def test_error(fig_input, error_class, message_pattern)
    application_configuration = new_configuration

    expect {
      Fig::Parser.new(application_configuration, false).parse_package(
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
        'foo_directory',
        'source description',
        fig_input
      )
    }.to raise_error(error_class, message_pattern)

    return
  end

  def test_user_input_error(fig_input, message_pattern)
    test_error(fig_input, Fig::UserInputError, message_pattern)

    return
  end

  def test_package_parse_error(
    fig_input, message_pattern = /source description/
  )
    test_error(fig_input, Fig::PackageParseError, message_pattern)

    return
  end

  describe 'base syntax' do
    it 'throws the correct exception on syntax error' do
      fig_package=<<-END
        this is invalid syntax
      END

      application_configuration = new_configuration

      expect {
        Fig::Parser.new(application_configuration, false).parse_package(
          Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
          'foo_directory',
          'source description',
          fig_package
        )
      }.to raise_error(
        Fig::PackageParseError
      )
    end

    it 'assigns the correct line and column number to Statement objects.' do
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

      application_configuration = new_configuration
      package = Fig::Parser.new(application_configuration, false).parse_package(
        Fig::PackageDescriptor.new('package_name', 'version', nil),
        'foo_directory',
        'source description',
        fig_package
      )

      package.walk_statements do
        |statement|

        case statement
          when Fig::Statement::Resource
            statement.line.should == 3
            statement.column.should == 9
          when Fig::Statement::Archive
            statement.line.should == 10
            statement.column.should == 10
          when Fig::Statement::Configuration
            statement.line.should == 12
            statement.column.should == 9
          when Fig::Statement::Include
            statement.line.should == 13
            statement.column.should == 17
          when Fig::Statement::Set
            statement.line.should == 15
            statement.column.should == 12
        end
      end
    end
  end

  describe 'validating URLs' do
    it 'passes valid, whitelisted ones' do
      fig_package=<<-FIG_PACKAGE
        resource http://example/is/awesome.tgz

        archive http://svpsvn/my/repo/is/cool.jar
      FIG_PACKAGE
      application_configuration = new_configuration
      application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

      package = Fig::Parser.new(application_configuration, false).parse_package(
        Fig::PackageDescriptor.new('package_name', 'version', nil),
        'foo_directory',
        'source description',
        fig_package
      )
      package.should_not == nil
    end

    it 'rejects non-whitelisted ones' do
      fig_package=<<-FIG_PACKAGE
        resource http://evil_url/is/bad.tgz

        archive http://evil_repo/my/repo/is/bad.jar
      FIG_PACKAGE
      application_configuration = new_configuration
      application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

      exception = nil
      begin
        package = Fig::Parser.new(application_configuration, false).parse_package(
          Fig::PackageDescriptor.new('package_name', '0.1.1', nil),
          'foo_directory',
          'source description',
          fig_package
        )
      rescue Fig::URLAccessError => exception
      end
      exception.should_not == nil
      exception.urls.should =~ %w<http://evil_url/is/bad.tgz http://evil_repo/my/repo/is/bad.jar>
      exception.descriptor.name.should == 'package_name'
      exception.descriptor.version.should == '0.1.1'
    end
  end

  describe 'command statements' do
    # TODO: Restore v1 grammar.
    # %w< 0 1 >.each do
    %w< 0 >.each do
      |version|

      describe %Q<in the v#{version} grammar> do
        it 'reject multiple commands in config file' do
          input = <<-"END_PACKAGE"
            grammar v#{version}
            config default
              command "echo foo"
              command "echo bar"
            end
          END_PACKAGE

          test_user_input_error(
            input,
            /found a second "command" statement within a "config" block/i
          )
        end

        it 'accept multiple configs, each with a single command' do
          test_no_parse_exception(<<-"END_PACKAGE")
            grammar v#{version}
            config default
              command "echo foo"
            end
            config another
              command "echo bar"
            end
          END_PACKAGE
        end

        it 'reject multiple configs where one has multiple commands' do
          input = <<-"END_PACKAGE"
            grammar v#{version}
            config default
              command "echo foo"
            end
            config another
              command "echo bar"
              command "echo baz"
            end
          END_PACKAGE

          test_user_input_error(
            input,
            /found a second "command" statement within a "config" block/i
          )
        end
      end
    end
  end

  describe 'path statements' do
    {
      ';'  => ';',
      ':'  => ':',
      '"'  => '"',
      '<'  => '<',
      '>'  => '>',
      '|'  => '|',
      ' '  => ' ',
      '\t' => "\t",
      '\r' => "\r",
      '\n' => "\n"
    }.each do
      |display, character|

      describe %Q<reject "#{display}" in a PATH component> do
        # TODO: Restore v1 grammar.
        # %w< 0 1 >.each do
        %w< 0 >.each do
          |version|

          it %Q<in the v#{version} grammar> do
            input = <<-"END_PACKAGE"
              grammar v#{version}
              config default
                append PATH_VARIABLE=#{character}
              end
            END_PACKAGE

            test_user_input_error(
              input, /(?i:invalid value for append).*\bPATH_VARIABLE\b/
            )
          end
        end
      end
    end
  end

  %w< archive resource >.each do
    |asset_type|

    describe "#{asset_type} statements" do
      %w< @ " < > | >.each do
        |character|

        it %Q<get a parse error with "#{character}" in a URL in the v0 grammar> do
          input = <<-"END_PACKAGE"
            #{asset_type} #{character}
          END_PACKAGE

          test_package_parse_error(input)
        end

        it %Q<reject "#{character}" in a URL in the v1 grammar> do
          pending 'removal of the block on the v1 format' do
            input = <<-"END_PACKAGE"
              grammar v1
              #{asset_type} #{character}
            END_PACKAGE

            test_user_input_error(
              input,
              %r<invalid url/path for #{asset_type} statement: "#{character}">i
            )
          end
        end
      end

      it %q<handles octothorpes in the URL in the v1 grammar> do
        pending 'removal of the block on the v1 format' do
          package = test_no_parse_exception(<<-"END_PACKAGE")
            grammar v1
            #{asset_type} 'foo#bar'
            config default
            end
          END_PACKAGE

          url = [package.archive_urls, package.resource_urls].flatten[0]
          url.should == 'foo#bar'
        end
      end

      describe %Q<handles plus signs in the path (e.g. for C++ libraries)> do
        # TODO: Restore v1 grammar.
        # %w< 0 1 >.each do
        %w< 0 >.each do
          |version|

          it %Q<in the v#{version} grammar> do
            test_no_parse_exception(<<-"END_PACKAGE")
              grammar v#{version}
              #{asset_type} testlib++.whatever
              config default
                append LIBPATH=@/testlib++
              end
            END_PACKAGE
          end
        end
      end
    end
  end
end
