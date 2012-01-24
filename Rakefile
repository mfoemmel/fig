# To build fig for ruby 1.8.7 on windows please see the README for instructions.
# It is not possible to do from the rake file anymore.

require 'rubygems'
require 'rake'
require 'fileutils'
include FileUtils

begin
  require 'jeweler'
  gems = [
    ['java',        'fig',    nil,                        ['runtime']              ], # Java
    ['ruby',        'fig',   'libarchive-static',         ['development','runtime']]
  ]

  gems.each do |platform, fig_name, libarchive_dep, deptypes|
    Jeweler::Tasks.new do |gemspec|
      gemspec.name = fig_name
      gemspec.summary = %Q<Fig is a utility for configuring environments and managing dependencies across a team of developers. (#{fig_name}/#{platform} version)>
      gemspec.description = %q<Fig is a utility for configuring environments and managing dependencies across a team of developers. Given a list of packages and a command to run, Fig builds environment variables named in those packages (e.g., CLASSPATH), then executes the command in that environment. The caller's environment is not affected.>
      gemspec.email = 'git@foemmel.com'
      gemspec.homepage = 'http://github.com/mfoemmel/fig'
      gemspec.authors = ['Matthew Foemmel']
      gemspec.platform = platform

      if not libarchive_dep.nil?
        deptypes.each { |deptype| gemspec.send("add_#{deptype}_dependency", libarchive_dep, '>= 1.0.0') }
      end

      gemspec.add_dependency              'highline',   '>= 1.6.2'
      gemspec.add_dependency              'log4r',      '>= 1.1.5'
      gemspec.add_dependency              'net-netrc',  '>= 0.2.2'
      gemspec.add_dependency              'net-sftp',   '>= 2.0.4'
      gemspec.add_dependency              'net-ssh',    '>= 2.0.15'
      gemspec.add_dependency              'polyglot',   '>= 0.2.9'
      gemspec.add_dependency              'rdoc',       '>= 3.12'
      gemspec.add_dependency              'json',       '>= 1.6.5'
      gemspec.add_dependency              'treetop',    '>= 1.4.2'
      gemspec.add_dependency              'ftp',        '>= 0.69'
      gemspec.add_development_dependency  'open4',      '>= 1.0.1'
      gemspec.add_development_dependency  'rspec',      '>= 2.8'

      gemspec.files =
          %w<bin/fig bin/fig-download VERSION Changes> \
        + Dir['lib/**/*.rb']                           \
        + Dir['lib/**/*.treetop']
      gemspec.executables = ['fig', 'fig-download']

      Jeweler::GemcutterTasks.new
    end

  end
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler.'
end

require 'rspec/core/rake_task'
desc 'Run RSpec tests.'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = []
  spec.rspec_opts << '--order rand'
end

#desc 'Run RSpec tests with coverage reporting via rcov.'
#RSpec::Core::RakeTask.new(:rcov) do |spec|
#  spec.rcov = true
#end

#desc 'Build gems and then fix fig18 gem file names.'
#task :figbuild => :build do
#  version = File.exist?('VERSION') ? File.read('VERSION').strip : ''
#end

task :simplecov do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

task :spec => 'check_dependencies:development'

task :spec do
  rm_rf './.fig'
end

task :default => :spec

require 'rdoc/task'
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
