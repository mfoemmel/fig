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
          command "echo foo"
        end
      END
    end

    it 'from v1 file input with a simple command statement' do
      check_published_grammar_version 0, <<-'END'
        grammar v1
        config default
          command "echo foo" end
        end
      END
    end

    it 'from v1 file input with a multi-component, mixed-quoting command statement' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        config default
          command echo "foo" 'bar baz' end
        end
      END
    end

    it 'from v1 file input with a command statement containing all keywords' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        config default
          command
            add
            append
            archive
            command
            config
            'end'       # Have to quote this one
            include
            override
            path
            resource
            retrieve
            set
          end
        end
      END
    end

    it 'from v1 file input with a single-quoted command statement (v1 currently, should change to v0 eventually)' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        config default
          command 'bar baz' end
        end
      END
    end

    it 'from v1 file input with a command statement containing an octothorpe' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        config default
          command "bar#baz" end
        end
      END
    end

    it 'from v1 file input with a command statement containing a double quote' do
      check_published_grammar_version 1, <<-'END'
        grammar v1
        config default
          command bar\"baz end
        end
      END
    end
  end
end

# vim: set fileencoding=utf8 :
