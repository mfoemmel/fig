# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'
require 'fig/statement/resource'
require 'fig/unparser/v1'

describe Fig::Unparser::V1 do
  let(:unparser) {
    Fig::Unparser::V1.new :emit_as_input, '<indent>', 1
  }

  describe 'unparses' do
    {
      Fig::Statement::Archive  => 'archive',
      Fig::Statement::Resource => 'resource',
    }.each_pair do
      |statement_class, keyword|

      describe keyword do
        it %q<«chocolate*pizza» with globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate*pizza', :glob_if_not_url)

          unparser.unparse([statement]).should ==
            %Q[<indent>#{keyword} "chocolate*pizza"\n]
        end

        it %q<«chocolate*pizza» without globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate*pizza', false)

          unparser.unparse([statement]).should ==
            %Q[<indent>#{keyword} 'chocolate*pizza'\n]
        end

        it %q<«chocolate\\pizza» with globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate\\pizza', :glob_if_not_url)

          unparser.unparse([statement]).should ==
            %Q[<indent>#{keyword} "chocolate\\\\pizza"\n]
        end

        it %q<«chocolate\\pizza» without globbing> do
          statement = statement_class.new(nil, nil, 'chocolate\\pizza', false)

          unparser.unparse([statement]).should ==
            %Q[<indent>#{keyword} 'chocolate\\\\pizza'\n]
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
