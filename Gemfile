# Used for bundler.  Not used to produce the actual gem; that's done in the
# Rakefile.

require 'rbconfig'

source 'http://rubygems.org'

ruby '1.9.2'

# All environments
gem 'colorize',          '>= 0.5.8'
gem 'highline',          '>= 1.6.2'
gem 'json',              '= 1.6.5' # Pinned due to TeamCity issues.
gem 'libarchive-static', '>= 1.0.0'
gem 'log4r',             '>= 1.1.5'
gem 'net-netrc',         '>= 0.2.2'
gem 'net-sftp',          '>= 2.0.4'
gem 'net-ssh',           '>= 2.0.15'
gem 'rdoc',              '>= 3.12'
gem 'sys-admin',         '>= 1.5.6'
gem 'treetop',           '>= 1.4.2'

group :development do
  gem 'open4',              '>= 1.0.1'
  gem 'bundler',            '>= 1.0.15'
  gem 'rake',               '>= 0.8.7'
  gem 'rspec',              '~> 2'
  gem 'rspec-core',         '>= 2.7.1'
  gem 'rspec-expectations', '>= 2.7.0'
  gem 'rspec-mocks',        '>= 2.7.0'

  if 1.9 <= RbConfig::CONFIG['ruby_version'].to_f
    gem 'simplecov',        '>= 0.6.2'
    gem 'simplecov-html',   '>= 0.5.3'
  end
end
