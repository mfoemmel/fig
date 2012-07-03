# Don't know what the idiomatic Ruby is for the situation where one wants to be
# able to pull the dependencies from one Rakefile into another is, but here's
# one way to do it.

def add_dependencies(gemspec)
  gemspec.add_dependency 'colorize',          '>= 0.5.8'
  gemspec.add_dependency 'highline',          '>= 1.6.2'
  gemspec.add_dependency 'json',              '>= 1.6.5'
  gemspec.add_dependency 'libarchive-static', '>= 1.0.0'
  gemspec.add_dependency 'log4r',             '>= 1.1.5'
  gemspec.add_dependency 'net-netrc',         '>= 0.2.2'
  gemspec.add_dependency 'net-sftp',          '>= 2.0.4'
  gemspec.add_dependency 'net-ssh',           '>= 2.0.15'
  gemspec.add_dependency 'polyglot',          '>= 0.2.9'
  gemspec.add_dependency 'rdoc',              '>= 3.12'
  gemspec.add_dependency 'sys-admin',         '>= 1.5.6'
  gemspec.add_dependency 'treetop',           '>= 1.4.2'
  gemspec.add_dependency 'unicode_utils',     '>= 1.0'

  return
end
