# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'

describe Fig::Statement::Archive do
  describe 'unparses' do
    it %q<«chocolate*pizza» with globbing> do
      statement =
        Fig::Statement::Archive.new(
          nil, nil, 'chocolate*pizza', :glob_if_not_url
        )

      statement.unparse('<indent>').should ==
        %q[<indent>archive "chocolate*pizza"]
    end
    it %q<«chocolate*pizza» without globbing> do
      statement =
        Fig::Statement::Archive.new(nil, nil, 'chocolate*pizza', false)

      statement.unparse('<indent>').should ==
        %q[<indent>archive 'chocolate*pizza']
    end
    it %q<«chocolate\pizza» with globbing> do
      statement =
        Fig::Statement::Archive.new(
          nil, nil, 'chocolate\pizza', :glob_if_not_url
        )

      statement.unparse('<indent>').should ==
        %q[<indent>archive "chocolate\\pizza"]
    end
    it %q<«chocolate\pizza» without globbing> do
      statement =
        Fig::Statement::Archive.new(nil, nil, 'chocolate\pizza', false)

      statement.unparse('<indent>').should ==
        %q[<indent>archive 'chocolate\pizza']
    end
  end
end

# vim: set fileencoding=utf8 :
