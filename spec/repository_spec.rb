require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'
require 'tempfile'

require 'fig/applicationconfiguration'
require 'fig/package/configuration'
require 'fig/package/publish'
require 'fig/package/resource'
require 'fig/repository'

setup_repository()

def create_local_repository()
  application_config = Fig::ApplicationConfiguration.new(FIG_REMOTE_DIR)
  repository = Fig::Repository.new(Fig::OS.new(nil), FIG_SPEC_BASE_DIRECTORY, "file://#{FIG_REMOTE_DIR}", application_config)
  return repository
end

def generate_package_statements
    resource_statement      = Fig::Package::Resource.new('fullpath')
    path_statement          = Fig::Package::Path.new('FOO', 'bar')
    configuration_statement = Fig::Package::Configuration.new('default', [path_statement])
    publish_statement       = Fig::Package::Publish.new('default', 'default')
    package_statements = [resource_statement] + [configuration_statement]
    package_statements << publish_statement

    return package_statements
end

describe 'Repository' do
  it 'cleans a package from the repository' do
    cleanup_repository

    repository = create_local_repository

    repository.list_packages.include?('foo/1.0.0').should be_false

    package_statements = generate_package_statements

    repository.publish_package(package_statements, 'foo', '1.0.0', false)

    repository.list_packages.include?('foo/1.0.0').should be_true

    repository.clean('foo','1.0.0')

    repository.list_packages.include?('foo/1.0.0').should be_false

    cleanup_repository
  end
end
