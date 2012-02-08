require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/applicationconfiguration'
require 'fig/packagedescriptor'
require 'fig/repository'
require 'fig/statement/configuration'
require 'fig/statement/path'
require 'fig/statement/publish'
require 'fig/statement/resource'

def create_local_repository()
  application_config = Fig::ApplicationConfiguration.new(FIG_REMOTE_DIR)
  repository = Fig::Repository.new(
    Fig::OperatingSystem.new(nil),
    FIG_SPEC_BASE_DIRECTORY,
    "file://#{FIG_REMOTE_DIR}",
    application_config
  )
  return repository
end

def generate_package_statements
    resource_statement      = Fig::Statement::Resource.new('fullpath')
    path_statement          = Fig::Statement::Path.new('FOO', 'bar')
    configuration_statement =
      Fig::Statement::Configuration.new(
        Fig::Package::DEFAULT_CONFIG, [path_statement]
      )
    publish_statement       = Fig::Statement::Publish.new()

    package_statements = [resource_statement] + [configuration_statement]
    package_statements << publish_statement

    return package_statements
end

describe 'Repository' do
  before(:each) do
    setup_test_environment
  end

  it 'cleans a package from the repository' do
    cleanup_test_environment

    repository = create_local_repository

    repository.list_packages.include?('foo/1.0.0').should be_false

    package_statements = generate_package_statements

    descriptor = Fig::PackageDescriptor.new('foo', '1.0.0', nil)
    repository.publish_package(package_statements, descriptor, false)

    repository.list_packages.include?('foo/1.0.0').should be_true

    repository.clean(descriptor)

    repository.list_packages.include?('foo/1.0.0').should be_false

    cleanup_test_environment
  end
end
