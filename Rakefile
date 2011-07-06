require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "fig"
    gem.summary = %Q{Fig is a utility for configuring environments and managing dependencies across a team of developers..}
    gem.description = %Q{Fig is a utility for configuring environments and managing dependencies across a team of developers. You give it a list of packages and a shell command to run; it creates an environment that includes those packages, then executes the shell command in it (the caller's environment is not affected).}
    gem.email = "git@foemmel.com"
    gem.homepage = "http://github.com/mfoemmel/fig"
    gem.authors = ["Matthew Foemmel"]
    if RUBY_PLATFORM == 'java'
       gem.platform = RUBY_PLATFORM
    end
    gem.add_dependency "libarchive", ">= 0.1.1" unless gem.platform.to_s == 'java'
    gem.add_dependency "net-ssh", ">= 2.0.15"
    gem.add_dependency "net-sftp", ">= 2.0.5"
    gem.add_dependency "net-netrc", ">= 0.2.2"
    gem.add_dependency "polyglot", ">= 0.2.9"
    gem.add_dependency "treetop", ">= 1.4.2"
    gem.add_dependency "highline", ">= 1.6.2"
    gem.add_development_dependency "rspec", "~> 1.3"
    gem.add_development_dependency "open4", ">= 1.0.1"
    gem.files = ["bin/fig", "bin/fig-download"] + Dir["lib/**/*.rb"] + Dir["lib/**/*.treetop"]
    gem.executables = ["fig", "fig-download"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.spec_opts << '--format nested'
  spec.spec_opts << '--color'
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "fig #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :clean do
    rm_rf "./tmp"
    rm "./resources.tar.gz"
end

desc "Build and install the Fig gem for local testing."
task :p do
  sh "rake build"
  sh "sudo gem install pkg/*.gem"
end
