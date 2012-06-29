# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'
require 'fig/statement/resource'

[Fig::Statement::Archive, Fig::Statement::Resource].each do
  |statement_type|

  describe statement_type do
    describe '.validate_and_process_escapes_in_url()' do
      it %q<does not modify «foo * bar» and says that it should be globbed> do
        original_url = %q<foo * bar>
        url = original_url.clone
        block_message = nil

        should_be_globbed =
          statement_type.validate_and_process_escapes_in_url(url) do
            |message| block_message = message
          end

        url.should == original_url
        should_be_globbed.should be_true
        block_message.should be_nil
      end
    end
  end
end

# vim: set fileencoding=utf8 :
