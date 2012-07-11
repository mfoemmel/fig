# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/resource'

describe Fig::Statement::Resource do
  describe 'unparses' do
    pending %q<«chocolate*pizza» with globbing> do
      statement =
        Fig::Statement::Resource.new(
          nil, nil, 'chocolate*pizza', :glob_if_not_url
        )

      statement.unparse('<indent>').should ==
        %q[<indent>resource "chocolate*pizza"]
    end
    pending %q<«chocolate*pizza» without globbing> do
      statement =
        Fig::Statement::Resource.new(nil, nil, 'chocolate*pizza', false)

      statement.unparse('<indent>').should ==
        %q[<indent>resource 'chocolate*pizza']
    end
    it %q<«chocolate\pizza» with globbing> do
      statement =
        Fig::Statement::Resource.new(
          nil, nil, 'chocolate\pizza', :glob_if_not_url
        )

      statement.unparse('<indent>').should ==
        %q[<indent>resource "chocolate\\pizza"]
    end
    pending %q<«chocolate\pizza» without globbing> do
      statement =
        Fig::Statement::Resource.new(nil, nil, 'chocolate\pizza', false)

      statement.unparse('<indent>').should ==
        %q[<indent>resource 'chocolate\pizza']
    end
  end
end

# vim: set fileencoding=utf8 :
