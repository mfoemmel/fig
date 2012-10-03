# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

def check_published_grammar_version(version, input = nil)
  if input
    fig %w< --publish foo/1.2.3 >, input, :fork => false
  end

  out, err =
    fig(%w< foo/1.2.3 --dump-package-definition-text >, :fork => false)

  if version == 0
    out.should =~ /^# grammar v0\b/
  else
    out.should =~ / ^ grammar [ ] v #{version} \b/x
  end

  err.should == ''

  return [out, err]
end

# vim: set fileencoding=utf8 :
