# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/grammar_spec_helper')

describe 'Fig' do
  describe %q<uses the correct grammar version in the package definition created for publishing> do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    %w< set append >.each do
      |option|

      it "for simple --#{option}" do
        fig(
          [%w< --publish foo/1.2.3>, "--#{option}", 'VARIABLE=VALUE'],
          :fork => false
        )

        check_published_grammar_version(0)
      end
    end
  end
end

# vim: set fileencoding=utf8 :
