# To build fig for ruby 1.8.7 on windows please see the README for instructions.
# It is not possible to do from the rake file anymore.

require 'fileutils'
require 'rake'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubygems'
require 'rubygems/package_task'

include FileUtils

$major_version = nil
$minor_version = nil
$patch_version = nil
version = nil

File.open('VERSION', 'r') do |file|
  version = file.gets
  matches = version.match(/(\d+)\.(\d+)\.(\d+)/)
  $major_version = matches[1]
  $minor_version = matches[2]
  $patch_version = matches[3]
end

def clean_git_working_directory?
  return %x<git ls-files --deleted --modified --others --exclude-standard> == ''
end

def tag_exists_in_local_repo(new_tag)
  tag_exists = false
  tag_list = %x<git tag>
  tags = tag_list.split("\n")
  tags.each do |tag|
    if tag.chomp == new_tag
      tag_exists = true
    end
  end

  return tag_exists
end

def create_git_tag(version)
  new_tag = "v#{version}"
  print "Checking for an existing #{new_tag} git tag... "
  if not tag_exists_in_local_repo(new_tag)
    puts 'Tag does not already exist.'
    puts "Creating #{new_tag} tag."
    %x<git tag #{new_tag}>
  else
    puts 'Tag exists.'
    return nil
  end

  if not tag_exists_in_local_repo(new_tag)
    puts "The tag was not successfully created. Aborting!"
    return nil
  end

  return new_tag
end

def push_to_remote_repo(new_tag)
  if new_tag != nil
    puts %Q<Pushing #{new_tag} tag to "origin" remote repository.>
    %x<git push origin #{new_tag}>
  end

  return
end

def tag_and_push_to_git(version)
  new_tag = nil
  if clean_git_working_directory?
    new_tag = create_git_tag(version)
    push_to_remote_repo(new_tag)
  else
    puts 'Cannot proceed with tag, push, and publish because your environment is not clean.'
    puts 'The status of your local git repository:'
    puts %x{git status 2>&1}
  end

  return new_tag != nil
end

def local_repo_is_updated?
  pull_results = %x{git pull 2>&1}
  if pull_results.chomp != "Already up-to-date."
    puts 'The local repository was not up-to-date:'
    puts pull_results
    puts 'Publish aborted.'

    return false
  end

  return true
end

def push_to_rubygems(version)
  print "Checking to see if pkg/fig-#{version}.gem exists... "
  if File.exists?("pkg/fig-#{version}.gem")
    puts 'File exists.'
    puts "Pushing pkg/fig-#{version}.gem to rubygems.org."
    puts %x{gem push pkg/fig-#{version}.gem 2>&1}

    return true
  else
    puts 'File does not exist.'
    puts 'Please build the gem before publishing.'

    return false
  end
end

def write_version_file()
  File.open('VERSION', 'w') do |file|
    file.print "#{$major_version}.#{$minor_version}.#{$patch_version}"
  end
end

def clean_up_after_testing()
  rm_rf './.fig'
end

fig_gemspec = Gem::Specification.new do |gemspec|
  gemspec.name = 'fig'
  gemspec.summary = 'Fig is a utility for configuring environments and managing dependencies across a team of developers.'
  gemspec.description = "Fig is a utility for configuring environments and managing dependencies across a team of developers. Given a list of packages and a command to run, Fig builds environment variables named in those packages (e.g., CLASSPATH), then executes the command in that environment. The caller's environment is not affected."
  gemspec.email = 'git@foemmel.com'
  gemspec.homepage = 'http://github.com/mfoemmel/fig'
  gemspec.authors = ['Matthew Foemmel']
  gemspec.platform = Gem::Platform::RUBY
  gemspec.version = version.chomp

  gemspec.add_dependency              'colorize',          '>= 0.5.8'
  gemspec.add_dependency              'highline',          '>= 1.6.2'
  gemspec.add_dependency              'json',              '>= 1.6.5'
  gemspec.add_dependency              'libarchive-static', '>= 1.0.0'
  gemspec.add_dependency              'log4r',             '>= 1.1.5'
  gemspec.add_dependency              'net-netrc',         '>= 0.2.2'
  gemspec.add_dependency              'net-sftp',          '>= 2.0.4'
  gemspec.add_dependency              'net-ssh',           '>= 2.0.15'
  gemspec.add_dependency              'polyglot',          '>= 0.2.9'
  gemspec.add_dependency              'rdoc',              '>= 3.12'
  gemspec.add_dependency              'sys-admin',         '>= 1.5.6'
  gemspec.add_dependency              'treetop',           '>= 1.4.2'

  gemspec.files = FileList[
    "Changes",
    "VERSION",
    "bin/*",
    "lib/fig/**/*",
  ].to_a

  gemspec.executables = ['fig', 'fig-download']
end

desc 'Run RSpec tests.'
RSpec::Core::RakeTask.new(:spec) do |spec|
  # Order is randomized so that we find inter-test dependencies.
  spec.rspec_opts = []
  spec.rspec_opts << '--order rand'
end
task :spec do
  clean_up_after_testing()
end

desc 'Run RSpec tests with SimpleCov.'
task :simplecov do
  ENV['FIG_COVERAGE'] = 'true'
end
RSpec::Core::RakeTask.new(:simplecov) do |spec|
  # Don't use '--order rand' like the standard "spec" task so that generated
  # SimpleCov command-names are consistent between runs.
end
task :simplecov do
  clean_up_after_testing()
end

desc 'Increments the major version number by one.'
task :increment_major_version do
    $major_version.succ!
    write_version_file()
end

desc 'Increments the minor version number by one.'
task :increment_minor_version do
    $minor_version.succ!
    write_version_file()
end

desc 'Increments the patch version number by one.'
task :increment_patch_version do
    $patch_version.succ!
    write_version_file()
end

Gem::PackageTask.new(fig_gemspec).define

desc 'Alias for the gem task.'
task :build => :gem

desc 'Tag the release, push the tag to the "origin" remote repository, and publish the rubygem to rubygems.org.'
task :publish do
  if local_repo_is_updated?
    if push_to_rubygems(version.chomp)
      tag_and_push_to_git(version.chomp)
    end
  end
end

task :default => :spec

RDoc::Task.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ''

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "fig #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Remove build products and temporary files.'
task :clean do
  %w< coverage pkg rdoc resources.tar.gz spec/runtime-work >.each do
    |path|
    rm_rf "./#{path}"
  end
end

desc 'Build and install the Fig gem for local testing.'
task :p do
  sh 'rake build'
  sh 'sudo gem install pkg/*.gem'
end
