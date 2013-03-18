# Used for bundler.  Not used to produce the actual gem; that's done in the
# Rakefile.

require 'rbconfig'

source 'http://rubygems.org'

( [1, 9, 2] <=> ( RUBY_VERSION.split(".").collect {|x| x.to_i} ) ) <= 0 or
  abort "Ruby v1.9.2 is required; this is v#{RUBY_VERSION}."

if RUBY_PLATFORM =~ /win32|mingw32/
  gem 'windows-pr',         '1.2.2'
  gem 'win32-security',     '0.1.4'
end

ruby RUBY_VERSION

# All environments
gem 'colorize',          '>= 0.5.8'
gem 'highline',          '>= 1.6.2'
gem 'json',              '>= 1.7.7'
gem 'libarchive-static', '>= 1.0.0'
gem 'log4r',             '>= 1.1.5'
gem 'open4',             '>= 1.0.1'
gem 'net-netrc',         '>= 0.2.2'
gem 'net-sftp',          '>= 2.0.4'
gem 'net-ssh',           '>= 2.0.15'
gem 'rdoc',              '>= 3.12'
gem 'treetop',           '>= 1.4.2'

group :development do
  gem 'bundler',            '>= 1.0.15'
  gem 'rake',               '>= 0.8.7'
  gem 'rspec',              '~> 2'
  gem 'rspec-core',         '>= 2.7.1'
  gem 'rspec-expectations', '>= 2.7.0'
  gem 'rspec-mocks',        '>= 2.7.0'
  gem 'simplecov',          '>= 0.6.2'
  gem 'simplecov-html',     '>= 0.5.3'
end
