require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  gems = [
    ['java',        'fig',    nil,                        ['runtime']              ], # Java
    [nil,           'fig',   'libarchive-static',         ['development','runtime']], # Linux (RHEL/Ubuntu) 1.9.2; Win 1.9.2
    ['x86_64-linux','fig18', 'libarchive-static',         ['runtime']              ], # Linux (RHEL/Ubuntu) 1.8.6 
    [nil,           'fig18', 'libarchive-static-ruby186', ['runtime']              ]  # Win 1.8.6
  ]
   
  gems.each do |platform, fig_name, libarchive_dep, deptypes|
    Jeweler::Tasks.new do |gemspec|
      gemspec.name = fig_name
      gemspec.summary = %Q{Fig is a utility for configuring environments and managing dependencies across a team of developers..}
      gemspec.description = %Q{Fig is a utility for configuring environments and managing dependencies across a team of developers. You give it a list of packages and a shell command to run; it creates an environment that includes those packages, then executes the shell command in it (the caller's environment is not affected).}
      gemspec.email = "git@foemmel.com"
      gemspec.homepage = "http://github.com/mfoemmel/fig"
      gemspec.authors = ["Matthew Foemmel"]
      gemspec.platform = platform if not platform.nil?

      deptypes.each do |deptype|
        gemspec.send("add_#{deptype}_dependency", libarchive_dep, "1.0.0") if not libarchive_dep.nil?
      end

      gemspec.add_dependency "net-ssh", ">= 2.0.15"
      gemspec.add_dependency "net-sftp", ">= 2.0.4"
      gemspec.add_dependency "net-netrc", ">= 0.2.2"
      gemspec.add_dependency "polyglot", ">= 0.2.9"
      gemspec.add_dependency "treetop", ">= 1.4.2"
      gemspec.add_dependency "highline", ">= 1.6.2"
      gemspec.add_development_dependency "rspec", "~> 1.3"
      gemspec.add_development_dependency "open4", ">= 1.0.1"
      gemspec.files = ["bin/fig", "bin/fig-download"] + Dir["lib/**/*.rb"] + Dir["lib/**/*.treetop"]
      gemspec.executables = ["fig", "fig-download"]
    end
    Jeweler::GemcutterTasks.new
  end
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

task :spec => "check_dependencies:development"

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
