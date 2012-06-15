require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/application_configuration'
require 'fig/logging'
require 'fig/not_found_error'
require 'fig/package_descriptor'
require 'fig/repository'
require 'fig/repository_error'
require 'fig/statement/configuration'
require 'fig/statement/path'

def create_local_repository()
  application_config = Fig::ApplicationConfiguration.new()
  application_config.base_whitelisted_url = FIG_REMOTE_URL
  application_config.remote_repository_url = FIG_REMOTE_URL

  repository = Fig::Repository.new(
    Fig::OperatingSystem.new(nil),
    FIG_HOME,
    application_config,
    [],   # publish listeners
    false # check include statement versions
  )
  repository.update_if_missing

  return repository
end

def generate_package_statements
  path_statement          = Fig::Statement::Path.new(nil, nil, 'FOO', 'bar')
  configuration_statement =
    Fig::Statement::Configuration.new(
      nil, nil, Fig::Package::DEFAULT_CONFIG, [path_statement]
    )

  package_statements = [configuration_statement]

  return package_statements
end

describe 'Repository' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it 'cleans a package from the repository' do
    repository = create_local_repository

    repository.list_packages.include?('foo/1.0.0').should be_false

    package_statements = generate_package_statements

    descriptor = Fig::PackageDescriptor.new('foo', '1.0.0', nil)
    repository.publish_package(package_statements, descriptor, false, nil, false)

    repository.list_packages.include?('foo/1.0.0').should be_true

    repository.clean(descriptor)

    repository.list_packages.include?('foo/1.0.0').should be_false
  end

  describe 'handles errors while installing packages' do
    it %q<that don't exist> do
      repository = create_local_repository

      repository.stub(:install_package) do
        raise Fig::NotFoundError.new('test NotFoundError')
      end

      Fig::Logging.should_receive(:fatal).with(
        /package not found.*package-name/i
      )

      descriptor = Fig::PackageDescriptor.new(
        'package-name', 'package-version', nil
      )
      expect {
        repository.get_package(descriptor)
      }.to raise_error(Fig::RepositoryError)
    end

    it 'that have some sort of installation issue' do
      repository = create_local_repository

      exception_message = 'test StandardError'
      repository.stub(:install_package) do
        raise StandardError.new(exception_message)
      end

      Fig::Logging.should_receive(:fatal).with(
        /install failed.*#{exception_message}/i
      )

      descriptor = Fig::PackageDescriptor.new(
        'package-name', 'package-version', nil
      )
      expect {
        repository.get_package(descriptor)
      }.to raise_error(Fig::RepositoryError)
    end
  end
end
