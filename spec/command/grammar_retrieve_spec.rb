# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it 'from v1 file input with a simple, unquoted retrieve statement' do
      check_published_grammar_version 0, <<-'END'
        grammar v1
        retrieve variable->value
      END
    end

    it 'from v1 file input with a simple, single-quoted retrieve statement (v1 currently, should change to v0 eventually)' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        retrieve variable->'value'
      END
    end

    it 'from v1 file input with a package-expanded, single-quoted retrieve statement' do
      check_published_grammar_version 0, <<-'END'
        grammar v1
        retrieve variable->"value[package]value"
      END
    end

    it 'from v1 file input with package-escaped, single-quoted retrieve statement' do
      # Backslashes are not allowed in v0 grammar, at all.  Not even to escape
      # "[package]".
      check_published_grammar_version 1, <<-'END'
        grammar v1
        retrieve variable->"value\[package]value"
      END
    end

    it 'from v1 file input with a retrieve statement containing whitespace' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        retrieve variable->"some value"
      END
    end

    it 'from v1 file input with a retrieve statement containing an octothorpe' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        retrieve variable->"some#value"
      END
    end
  end
end

# vim: set fileencoding=utf8 :
