# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it 'from unversioned file input with a simple command statement' do
      check_published_grammar_version 0, <<-'END'
        config default
          command "echo"
        end
      END
    end

    it 'from v1 file input with a simple command statement' do
      check_published_grammar_version 0, <<-'END'
        grammar v1
        config default
          command "echo" end
        end
      END
    end

    # Need test of "echo keywords-other-than-end"
  end
end

# vim: set fileencoding=utf8 :
