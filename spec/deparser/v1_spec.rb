# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'
require 'fig/statement/resource'
require 'fig/deparser/v1'

describe Fig::Deparser::V1 do
  let(:deparser) {
    Fig::Deparser::V1.new :emit_as_input, '<indent>', 1
  }

  describe 'deparses' do
    {
      Fig::Statement::Archive  => 'archive',
      Fig::Statement::Resource => 'resource',
    }.each_pair do
      |statement_class, keyword|

      describe keyword do
        it %q<«chocolate*pizza» with globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate*pizza', :glob_if_not_url)

          deparser.deparse([statement]).should ==
            %Q[<indent>#{keyword} "chocolate*pizza"\n]
        end

        it %q<«chocolate*pizza» without globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate*pizza', false)

          deparser.deparse([statement]).should ==
            %Q[<indent>#{keyword} 'chocolate*pizza'\n]
        end

        it %q<«chocolate\\pizza» with globbing> do
          statement =
            statement_class.new(nil, nil, 'chocolate\\pizza', :glob_if_not_url)

          deparser.deparse([statement]).should ==
            %Q[<indent>#{keyword} "chocolate\\\\pizza"\n]
        end

        it %q<«chocolate\\pizza» without globbing> do
          statement = statement_class.new(nil, nil, 'chocolate\\pizza', false)

          deparser.deparse([statement]).should ==
            %Q[<indent>#{keyword} 'chocolate\\\\pizza'\n]
        end

        it %q<«chocolate'"pizza»> do
          statement = statement_class.new(nil, nil, %q<chocolate'"pizza>, false)

          deparser.deparse([statement]).should ==
            %Q[<indent>#{keyword} 'chocolate\\'"pizza'\n]
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
