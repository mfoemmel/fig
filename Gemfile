# Used for bundler.  Not used to produce the actual gem; that's done in the
# Rakefile.

require 'rbconfig'

source 'http://rubygems.org'

( [2, 0, 0] <=> ( RUBY_VERSION.split(".").collect {|x| x.to_i} ) ) <= 0 or
  abort "Ruby v2.0.0 is required; this is v#{RUBY_VERSION}."

if RUBY_PLATFORM =~ /win32|mingw32/
  gem 'windows-pr',         '1.2.2'
  gem 'win32-security',     '0.1.4'
end

ruby RUBY_VERSION

# All environments
gem 'colorize',          '>= 0.5.8'
gem 'highline',          '>= 1.6.19'
gem 'json',              '>= 1.8'
gem 'libarchive-static', '>= 1.0.5'
gem 'log4r',             '>= 1.1.5'
gem 'net-netrc',         '>= 0.2.2'
gem 'net-sftp',          '>= 2.1.2'
gem 'net-ssh',           '>= 2.6.7'
gem 'rdoc',              '>= 4'
gem 'treetop',           '>= 1.4.14'

group :development do
  gem 'bundler',            '>= 1.0.15'
  gem 'rake',               '>= 0.8.7'
  gem 'rspec',              '~> 2'
  gem 'simplecov',          '>= 0.6.2'
  gem 'simplecov-html',     '>= 0.5.3'
end
