# coding: utf-8

# Don't know what the idiomatic Ruby is for the situation where one wants to be
# able to pull the dependencies from one Rakefile into another is, but here's
# one way to do it.

require 'rbconfig'

def add_dependencies(gemspec)
  gemspec.add_dependency 'colorize',          '>= 0.5.8'
  gemspec.add_dependency 'highline',          '>= 1.6.19'
  gemspec.add_dependency 'json',              '>= 1.8'
  gemspec.add_dependency 'libarchive-static', '>= 1.0.5'
  gemspec.add_dependency 'log4r',             '>= 1.1.5'
  gemspec.add_dependency 'net-netrc',         '>= 0.2.2'
  gemspec.add_dependency 'net-sftp',          '>= 2.1.2'
  gemspec.add_dependency 'net-ssh',           '>= 2.6.7'
  gemspec.add_dependency 'rdoc',              '>= 4'
  gemspec.add_dependency 'treetop',           '>= 1.4.14'

  gemspec.add_development_dependency 'bundler',         '>= 1.0.15'
  gemspec.add_development_dependency 'rake',            '>= 0.8.7'
  gemspec.add_development_dependency 'rspec',           '~> 2'
  gemspec.add_development_dependency 'simplecov',       '>= 0.6.2'
  gemspec.add_development_dependency 'simplecov-html',  '>= 0.5.3'

  gemspec.required_ruby_version = '>= 2.0.0'

  return
end
