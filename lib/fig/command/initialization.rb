# coding: utf-8

# This is not a normal module/class.  It contains code to be run by bin/fig and
# bin/fig-debug just after process startup.

( [2, 0, 0] <=> ( RUBY_VERSION.split(".").collect {|x| x.to_i} ) ) <= 0 or
  abort "Ruby v2.0.0 is required; this is v#{RUBY_VERSION}."

if ENV['FIG_COVERAGE']
  require File.expand_path(
    File.join(
      File.dirname(__FILE__), %w< coverage_support.rb >
    )
  )
end

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), %w< .. .. > ))

require 'rubygems'

require 'fig/command'
