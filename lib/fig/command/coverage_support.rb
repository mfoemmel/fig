# coding: utf-8

# This is not a normal module/class.  It contains code to be run by bin/fig and
# bin/fig-debug when doing coverage.

# Depends upon setup done by spec/spec_helper.rb.
if ! ENV['FIG_COVERAGE_RUN_COUNT'] || ! ENV['FIG_COVERAGE_ROOT_DIRECTORY']
  $stderr.puts \
    'FIG_COVERAGE_RUN_COUNT or FIG_COVERAGE_ROOT_DIRECTORY not set. Cannot do coverage correctly.'
  exit 1
end

require 'simplecov'

# Normal load of .simplecov does not work because SimpleCov assumes that
# everything is relative to the current directory.  The manipulation of
# SimpleCov.root below takes care of most things, but that doesn't affect
# .simplecov handling done in the "require 'simplecov'" above.
load File.expand_path(
  File.join(ENV['FIG_COVERAGE_ROOT_DIRECTORY'], '.simplecov')
)

# We may run the identical fig command-line multiple times, so we need to give
# additional value to make the run name unique.
SimpleCov.command_name(
  "fig run #{ENV['FIG_COVERAGE_RUN_COUNT']} (#{ARGV.join(' ')})"
)
SimpleCov.root ENV['FIG_COVERAGE_ROOT_DIRECTORY']

SimpleCov.at_exit do
  # Have to invoke result() in order to get coverage data saved.
  #
  # Default at_exit() further invokes format():
  #
  #    1) We save time by not doing it on each fig run and let the rspec run
  #       handle that.
  #    2) The formatter emits a message to stdout, which screws up tests of
  #       the fig output.
  SimpleCov.result
end

SimpleCov.start
