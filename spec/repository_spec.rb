require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/application_configuration'
require 'fig/package_descriptor'
require 'fig/repository'
require 'fig/statement/configuration'
require 'fig/statement/path'
require 'fig/statement/resource'

def create_local_repository()
  application_config = Fig::ApplicationConfiguration.new(FIG_REMOTE_URL)

  repository = Fig::Repository.new(
    Fig::OperatingSystem.new(nil),
    FIG_HOME,
    application_config,
    nil,   # remote user
    false # check include statement versions
  )
  repository.update_if_missing

  return repository
end

def generate_package_statements
  resource_statement      = Fig::Statement::Resource.new(nil, nil, FIG_FILE_GUARANTEED_TO_EXIST)
  path_statement          = Fig::Statement::Path.new(nil, nil, 'FOO', 'bar')
  configuration_statement =
    Fig::Statement::Configuration.new(
      nil, nil, Fig::Package::DEFAULT_CONFIG, [path_statement]
    )

  package_statements = [resource_statement] + [configuration_statement]

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
    repository.publish_package(package_statements, descriptor, false)

    repository.list_packages.include?('foo/1.0.0').should be_true

    repository.clean(descriptor)

    repository.list_packages.include?('foo/1.0.0').should be_false

    clean_up_test_environment
  end
end
