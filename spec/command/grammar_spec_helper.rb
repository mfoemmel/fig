# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

def check_published_grammar_version(version)
  out, err =
    fig(%w< foo/1.2.3 --dump-package-definition-text >, :fork => false)

  if version == 0
    out.should =~ /^# grammar v0\b/
  else
    out.should =~ / ^ grammar [ ] v #{version} \b/x
  end

  err.should == ''

  return
end

# vim: set fileencoding=utf8 :
